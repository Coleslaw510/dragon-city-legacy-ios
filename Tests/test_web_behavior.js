#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const listeners = {};
const nodes = [];
const document = {
    head: { appendChild(node) { nodes.push(node); } },
    querySelector(selector) {
        if (selector === 'meta[name="viewport"]') return nodes.find(n => n.name === 'viewport') || null;
        return null;
    },
    getElementById(id) { return nodes.find(n => n.id === id) || null; },
    createElement(tagName) { return { tagName }; },
    addEventListener(type, handler, options) { listeners[type] = { handler, options }; }
};
let messages = 0;
let clearedSelection = 0;
let time = 1000;
const fakeDate = { now: () => time };
const window = {
    webkit: { messageHandlers: { nativeTap: { postMessage() { messages += 1; } } } },
    addEventListener(type, handler, options) { listeners[`window:${type}`] = { handler, options }; },
    getSelection() { return { isCollapsed: false, removeAllRanges() { clearedSelection += 1; } }; }
};
const source = fs.readFileSync(path.join(__dirname, '..', 'DragonCityLegacy', 'WebBehavior.js'), 'utf8');
vm.runInNewContext(source, { document, window, Date: fakeDate, Math });

assert.match(document.querySelector('meta[name="viewport"]').content, /user-scalable=no/);
assert.match(document.getElementById('dclegacy-native-page-rules').textContent, /user-select: none/);
listeners.DOMContentLoaded.handler();
listeners['window:load'].handler();
assert.strictEqual(nodes.filter(n => n.id === 'dclegacy-native-page-rules').length, 1);
assert.strictEqual(listeners.touchstart.options.passive, true);
assert.strictEqual(listeners.touchend.options.passive, true);

const point = (x, y) => ({ clientX: x, clientY: y });
listeners.touchstart.handler({ touches: [point(10, 10)] });
time += 100;
listeners.touchend.handler({ changedTouches: [point(12, 12)] });
assert.strictEqual(messages, 1, 'a tap triggers one native message');
listeners.touchstart.handler({ touches: [point(10, 10)] });
time += 100;
listeners.touchend.handler({ changedTouches: [point(50, 50)] });
assert.strictEqual(messages, 1, 'a drag does not trigger feedback');
listeners.touchstart.handler({ touches: [point(10, 10)] });
time += 800;
listeners.touchend.handler({ changedTouches: [point(10, 10)] });
assert.strictEqual(messages, 1, 'a long touch does not trigger feedback');
listeners.touchstart.handler({ touches: [point(10, 10)] });
listeners.touchcancel.handler();
listeners.touchend.handler({ changedTouches: [point(10, 10)] });
assert.strictEqual(messages, 1, 'a cancelled touch does not trigger feedback');
let prevented = 0;
listeners.selectstart.handler({ preventDefault() { prevented += 1; } });
listeners.contextmenu.handler({ preventDefault() { prevented += 1; } });
listeners.dblclick.handler({ preventDefault() { prevented += 1; } });
assert.strictEqual(prevented, 3);
listeners.selectionchange.handler();
assert.strictEqual(clearedSelection, 1);
console.log('Web behavior tests passed.');
