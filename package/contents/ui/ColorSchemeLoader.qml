/*
    SPDX-FileCopyrightText: 2026 Samed Yolcu
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import "../code/colorscheme.js" as ColorScheme

// Loads the colors of a KDE color scheme file. `colors` is null while
// following the desktop (empty path) or when the file can't be read.
QtObject {
    id: loader

    property string path
    property var colors: null

    readonly property CommandRunner runner: CommandRunner {}

    function reload() {
        const requested = path;
        if (requested === "") {
            colors = null;
            return;
        }
        const command = ColorScheme.readCommand(requested);
        if (command === null) {
            colors = null;
            return;
        }
        runner.run(command, (exitCode, stdout) => {
            if (requested === loader.path) {
                loader.colors = exitCode === 0 ? ColorScheme.parse(stdout, Qt.locale().name) : null;
            }
        });
    }

    onPathChanged: reload()
    Component.onCompleted: reload()
}
