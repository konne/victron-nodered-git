#!/usr/bin/env node
'use strict';

// Preserve executable JavaScript settings instead of serializing them as JSON.
const fs = require('fs');
const path = require('path');
const target = path.resolve(process.argv[2]);
const exists = fs.existsSync(target);
const source = exists ? fs.readFileSync(target, 'utf8') : 'module.exports = {};\n';
const config = exists ? require(target) : {};
if (!config || typeof config !== 'object' || Array.isArray(config)) {
    throw new Error('settings-user.js must export a settings object');
}
const projects = config.editorTheme && config.editorTheme.projects;
if (projects && projects.enabled === true && projects.workflow && projects.workflow.mode) {
    console.log('unchanged');
    process.exit(0);
}

const override = `
// Added by victron-nodered-git; preserve all existing settings above.
;(function () {
    const cfg = module.exports;
    if (!cfg.editorTheme) cfg.editorTheme = {};
    if (!cfg.editorTheme.projects) cfg.editorTheme.projects = {};
    cfg.editorTheme.projects.enabled = true;
    if (!cfg.editorTheme.projects.workflow) cfg.editorTheme.projects.workflow = {};
    if (!cfg.editorTheme.projects.workflow.mode) cfg.editorTheme.projects.workflow.mode = 'manual';
})();
`;

fs.mkdirSync(path.dirname(target), { recursive: true });
const original = fs.statSync(exists ? target : path.dirname(target));
const temporary = target + '.tmp-' + process.pid;
try {
    if (exists) {
        fs.copyFileSync(target, target + '.backup-' + Date.now(), fs.constants.COPYFILE_EXCL);
    }
    fs.writeFileSync(temporary, source + '\n' + override, { flag: 'wx', mode: 0o600 });
    fs.chownSync(temporary, original.uid, original.gid);
    fs.chmodSync(temporary, exists ? original.mode & 0o777 : 0o600);
    fs.renameSync(temporary, target);
} finally {
    if (fs.existsSync(temporary)) fs.unlinkSync(temporary);
}
console.log('changed');
