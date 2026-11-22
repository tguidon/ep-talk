# EP Talk startup script for the EP-2350 FX-MIC.
# Signals use the four sample slots; config.json makes all presets clean.
# No USB prints or file operations run in the periodic audio callback.

exec(open('/rom/main.py').read())
import time

_ep_stock = python_callback

def _ep_load_samples():
    # Load explicitly: some stock ROM versions have a broken optional
    # sample/duck config parser. Default ducking is zero (voice stays live).
    for slot in range(4):
        sample = open('/fat/ep-talk/%d.wav' % slot, 'rb')
        try:
            loaded = spl.load_wav(slot, sample, 'oneshot')
        finally:
            sample.close()
        if loaded is False:
            raise RuntimeError('Could not load EP Talk signal sample')

_ep_load_samples()
_ep_code = ((0, 0, 0, 0), (0, 1, 1, 2), (1, 0, 1, 1), (1, 1, 0, 3))
_ep_now = time.ticks_ms()
_ep_state = {
    'p': bool(ui.sw(4)), 'o': not bool(ui.sw(2)),
    'pc': bool(ui.sw(4)), 'oc': not bool(ui.sw(2)),
    'pt': _ep_now, 'ot': _ep_now,
    'pending': [], 'word': (), 'index': 0, 'next': _ep_now,
    'last': time.ticks_add(_ep_now, -700), 'ticks': 0,
}

def ep_talk_status():
    print('EPTALK2', int(_ep_state['p']), int(_ep_state['o']), _ep_state['ticks'])

def _ep_paddle_value():
    # sw(4) closes at the start of travel. Gripping the mic to press orange
    # can close it while handle() stays near zero. Require deliberate travel,
    # then retain the hold until the handle returns and the switch opens.
    held = _ep_state['p']
    position = ui.handle()
    switch = bool(ui.sw(4))
    if not held and switch and position >= 0.50:
        return True
    if held and not switch and position <= 0.20:
        return False
    return held

def _ep_audio_tick():
    s = _ep_state
    now = time.ticks_ms()
    changed = False
    for key, value in (('p', _ep_paddle_value()), ('o', not bool(ui.sw(2)))):
        if value != s[key + 'c']:
            s[key + 'c'] = value
            s[key + 't'] = now
        elif value != s[key] and time.ticks_diff(now, s[key + 't']) >= 45:
            s[key] = value
            changed = True
    if changed:
        if len(s['pending']) >= 8:
            s['pending'] = []
        s['pending'].append(int(s['p']) + 2 * int(s['o']))
    if not s['word'] and time.ticks_diff(now, s['next']) >= 0 and (s['pending'] or time.ticks_diff(now, s['last']) >= 700):
        value = s['pending'].pop(0) if s['pending'] else int(s['p']) + 2 * int(s['o'])
        s['word'] = _ep_code[value]
        s['index'] = 0
        s['last'] = now
    if s['word'] and time.ticks_diff(now, s['next']) >= 0:
        spl.trigger(-1, s['word'][s['index']], True)
        s['index'] += 1
        s['next'] = time.ticks_add(now, 30)
        if s['index'] == 4:
            s['word'] = ()
            # An explicit quiet interval prevents adjacent state reports from
            # being assembled into a false release or orange-button press.
            s['next'] = time.ticks_add(now, 130)
    s['ticks'] += 1

def python_callback(message):
    try:
        kind, value = message >> 16, message & 0xFFFF
        # White would play an unframed sample; orange must not switch presets
        # during a signal.
        if kind in (1, 2) and value in (0, 2):
            return
        _ep_stock(message)
        if kind == 4 and value == 1:
            _ep_load_samples()
            _ep_state['word'] = ()
        if kind == 3:
            _ep_audio_tick()
    except Exception as error:
        # Restore the stock callback if our script fails. Never print here:
        # USB output can block forever after the data cable is removed.
        ui.callback(_ep_stock)
        try:
            import sys
            log = open('/fat/ep-talk-error.log', 'w')
            sys.print_exception(error, log)
            log.close()
        except:
            pass

ui.callback(python_callback)
