(() => {
    'use strict';

    function installPageRules() {
        if (!document.head) return;
        let viewport = document.querySelector('meta[name="viewport"]');
        if (!viewport) {
            viewport = document.createElement('meta');
            viewport.name = 'viewport';
            document.head.appendChild(viewport);
        }
        viewport.content = 'width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=1, user-scalable=no';

        if (!document.getElementById('dclegacy-native-page-rules')) {
            const style = document.createElement('style');
            style.id = 'dclegacy-native-page-rules';
            style.textContent = '* { -webkit-user-select: none !important; user-select: none !important; -webkit-touch-callout: none !important; }';
            document.head.appendChild(style);
        }
    }

    installPageRules();
    document.addEventListener('DOMContentLoaded', installPageRules, { once: true });
    window.addEventListener('load', installPageRules, { once: true });
    document.addEventListener('selectstart', event => event.preventDefault(), true);
    document.addEventListener('contextmenu', event => event.preventDefault(), true);
    document.addEventListener('dblclick', event => event.preventDefault(), true);
    document.addEventListener('selectionchange', () => {
        const selection = window.getSelection();
        if (selection && !selection.isCollapsed) selection.removeAllRanges();
    });

    // Observe touch gestures without cancelling them; do not vibrate for a drag.
    let start = null;
    document.addEventListener('touchstart', event => {
        if (event.touches.length !== 1) { start = null; return; }
        const touch = event.touches[0];
        start = { x: touch.clientX, y: touch.clientY, time: Date.now() };
    }, { passive: true });
    document.addEventListener('touchcancel', () => { start = null; }, { passive: true });
    document.addEventListener('touchend', event => {
        if (!start || event.changedTouches.length !== 1) { start = null; return; }
        const touch = event.changedTouches[0];
        const distance = Math.hypot(touch.clientX - start.x, touch.clientY - start.y);
        const elapsed = Date.now() - start.time;
        start = null;
        if (distance <= 12 && elapsed <= 700) {
            const handler = window.webkit && window.webkit.messageHandlers.nativeTap;
            if (handler) handler.postMessage(null);
        }
    }, { passive: true });
})();
