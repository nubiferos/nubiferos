/* sessionState.js
 *
 * NubiferOS Context Indicator - session-state helpers (Req 5.2)
 *
 * Pure functions that turn the non-secret `sessions` metadata from the
 * workspace config JSON (~/.config/nubifer/workspaces/<id>.json, written by
 * nubifer-creds login/logout) into display state for the indicator:
 *
 *   sessions = {
 *       "aws": {
 *           "mode": "sso",
 *           "identity": "arn:aws:sts::123...",   // never a token
 *           "expires_at": "2026-07-20T14:00:00Z",
 *           "logged_in_at": "..."
 *       }, ...
 *   }
 *
 * Kept free of GNOME Shell imports so it can be exercised by standalone gjs
 * (see tests/test_session_state.py). Everything is defensive: malformed
 * input yields an empty result, never an exception.
 */

'use strict';

// Mirrors SESSION_PROVIDERS in nubifer-creds
var SESSION_PROVIDER_ORDER = ['aws', 'azure', 'gcp'];

// "Expiring soon" threshold (Req 5.2)
var EXPIRING_SOON_SECONDS = 15 * 60;

// Provider keys are used to build `nubifer-creds login -t <p>` commands, so
// only accept conservative identifiers.
var PROVIDER_KEY_RE = /^[A-Za-z0-9_-]+$/;

// Timezone designator at the end of an ISO-ish timestamp
var TZ_SUFFIX_RE = /(Z|[+-]\d{2}:?\d{2})$/;

/**
 * Parse a provider expiry timestamp to epoch milliseconds.
 *
 * Mirrors _parse_session_timestamp() in nubifer-creds: accepts ISO 8601
 * with 'Z', numeric offsets, or a trailing 'UTC'; naive timestamps are
 * treated as UTC. Returns null when unparseable.
 */
function parseExpiry(value) {
    if (typeof value !== 'string')
        return null;
    let ts = value.trim();
    if (ts === '')
        return null;
    if (ts.endsWith('UTC'))
        ts = ts.slice(0, -3).trim();
    // Providers sometimes separate date and time with a space
    if (ts.length > 10 && ts.charAt(10) === ' ')
        ts = ts.slice(0, 10) + 'T' + ts.slice(11);
    // Naive timestamps are UTC (matches nubifer-creds)
    if (ts.includes('T') && !TZ_SUFFIX_RE.test(ts))
        ts += 'Z';
    const ms = Date.parse(ts);
    return Number.isNaN(ms) ? null : ms;
}

/**
 * State of a single session entry at `nowMs`.
 *
 * Returns { state: 'active'|'expiring'|'expired', expiresMs: number|null }
 * or null when the entry is not a usable object. An entry without a
 * parseable expiry counts as 'active' (same as nubifer-creds status).
 */
function sessionState(session, nowMs) {
    if (!session || typeof session !== 'object' || Array.isArray(session))
        return null;
    const expiresMs = parseExpiry(session.expires_at);
    let state = 'active';
    if (expiresMs !== null) {
        if (expiresMs <= nowMs)
            state = 'expired';
        else if (expiresMs - nowMs < EXPIRING_SOON_SECONDS * 1000)
            state = 'expiring';
    }
    return { state, expiresMs };
}

/**
 * Local-time 'HH:MM' for an epoch-milliseconds expiry.
 */
function formatExpiryTime(expiresMs) {
    const d = new Date(expiresMs);
    const hh = String(d.getHours()).padStart(2, '0');
    const mm = String(d.getMinutes()).padStart(2, '0');
    return `${hh}:${mm}`;
}

/**
 * Turn a workspace `sessions` object into an ordered list of display
 * entries: { provider, mode, identity, state, expiresHHMM }.
 *
 * Malformed input (missing key, wrong type, junk entries) yields [] or
 * skips the bad entries - it never throws.
 */
function computeSessionStates(sessions, nowMs) {
    if (!sessions || typeof sessions !== 'object' || Array.isArray(sessions))
        return [];

    const providers = Object.keys(sessions).filter(
        p => PROVIDER_KEY_RE.test(p));
    providers.sort((a, b) => {
        const ia = SESSION_PROVIDER_ORDER.indexOf(a);
        const ib = SESSION_PROVIDER_ORDER.indexOf(b);
        return (ia === -1 ? 99 : ia) - (ib === -1 ? 99 : ib)
            || a.localeCompare(b);
    });

    const out = [];
    for (const provider of providers) {
        const session = sessions[provider];
        const st = sessionState(session, nowMs);
        if (!st)
            continue;
        out.push({
            provider,
            mode: (typeof session.mode === 'string' && session.mode !== '')
                ? session.mode : 'sso',
            identity: (typeof session.identity === 'string')
                ? session.identity : null,
            state: st.state,
            expiresHHMM: st.expiresMs !== null
                ? formatExpiryTime(st.expiresMs) : null,
        });
    }
    return out;
}

/**
 * Overall severity across entries from computeSessionStates():
 * 'expired' > 'expiring' > null (nothing to surface).
 */
function worstSessionState(states) {
    if (!Array.isArray(states))
        return null;
    let worst = null;
    for (const s of states) {
        if (s && s.state === 'expired')
            return 'expired';
        if (s && s.state === 'expiring')
            worst = 'expiring';
    }
    return worst;
}
