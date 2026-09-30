/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.plasma5support as Plasma5Support

// Runs read-only shell commands through plasma5support's executable engine
// and calls back with (exitCode, stdout, stderr). Each call gets a unique
// source name (a trailing shell comment), so identical commands never share
// a cached result.
QtObject {
    id: runner

    property int sequence: 0
    property var callbacks: ({})

    function run(command, callback) {
        const source = command + " # " + (++sequence);
        callbacks[source] = callback;
        executable.connectSource(source);
    }

    property Plasma5Support.DataSource executable: Plasma5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            const callback = runner.callbacks[sourceName];
            delete runner.callbacks[sourceName];
            if (callback) {
                callback(data["exit code"], data["stdout"], data["stderr"]);
            }
        }
    }
}
