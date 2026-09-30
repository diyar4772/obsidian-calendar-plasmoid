// SPDX-FileCopyrightText: 2026 Samed Yolcu
// SPDX-License-Identifier: GPL-2.0-or-later

// KWin script that brings Obsidian's window to the front.
//
// Obsidian can't raise its own window after a click in the widget: Plasma's
// focus stealing prevention only lets the application the user is working
// with activate windows. KWin scripts run inside the compositor, so the
// widget loads this script over D-Bus (org.kde.KWin /Scripting) right after
// it opens an obsidian:// link, runs it once and unloads it again
// (Paths.activateCommand()). It only activates a window; it reads nothing
// else and changes nothing.
//
// The window that asks for attention wins (Obsidian asked to be shown but
// was refused), otherwise the Obsidian window used last. When Obsidian isn't
// running yet, its first window is activated when it appears.

// Native and AppImage builds use the class "obsidian", the Flatpak's
// Wayland app id is md.obsidian.Obsidian.
function isObsidian(window) {
    if (!window || !window.normalWindow) {
        return false;
    }
    const names = [window.resourceClass, window.resourceName, window.desktopFileName]
        .map(function (s) { return String(s || "").toLowerCase(); });
    return names.indexOf("obsidian") !== -1 || names.indexOf("md.obsidian.obsidian") !== -1;
}

// `windows` is stacking order, bottom to top.
function pickWindow(windows) {
    const candidates = windows.filter(isObsidian);
    for (let i = candidates.length - 1; i >= 0; i--) {
        if (candidates[i].demandsAttention) {
            return candidates[i];
        }
    }
    return candidates.length > 0 ? candidates[candidates.length - 1] : null;
}

function activate(window) {
    if (window.minimized) {
        window.minimized = false;
    }
    workspace.activeWindow = window;
}

const target = pickWindow(workspace.stackingOrder);
if (target) {
    activate(target);
} else {
    const onWindowAdded = function (window) {
        if (isObsidian(window)) {
            workspace.windowAdded.disconnect(onWindowAdded);
            activate(window);
        }
    };
    workspace.windowAdded.connect(onWindowAdded);
}
