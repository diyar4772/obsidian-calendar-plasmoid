.pragma library
.import "dateformat.js" as DateFormat
.import "locales.js" as Locales

// Paths, shell commands and obsidian:// URIs.
//
// Every command here is read-only and built from a fixed template; the only
// user-supplied parts are paths, and those always go through shellQuote().
// Output is NUL-separated, so file names can't break parsing.

// Exit codes the commands use to report missing directories.
const EXIT_NO_VAULT = 3;      // the vault path doesn't exist
const EXIT_NOT_A_VAULT = 4;   // it exists but has no .obsidian folder
const EXIT_NO_FOLDER = 5;     // the notes folder doesn't exist (yet)

// Only the beginning of each note is read to count words. The Calendar
// plugin draws at most 5 dots, so this is plenty for any sensible
// words-per-dot value and keeps huge notes cheap.
const READ_LIMIT_BYTES = 262144;

// Quotes a string for POSIX sh: wrap in single quotes and write each ' as '\''.
// Returns null for strings that can't be passed to a command (NUL bytes).
function shellQuote(value) {
    const s = String(value);
    if (s.indexOf("\0") !== -1) {
        return null;
    }
    return "'" + s.replace(/'/g, "'\\''") + "'";
}

// Joins path segments with "/", dropping empty segments but keeping a leading "/".
function joinPath() {
    const parts = [];
    for (let i = 0; i < arguments.length; i++) {
        const segments = String(arguments[i]).split("/");
        for (let j = 0; j < segments.length; j++) {
            if (segments[j] !== "") {
                parts.push(segments[j]);
            }
        }
    }
    const absolute = arguments.length > 0 && String(arguments[0]).charAt(0) === "/";
    return (absolute ? "/" : "") + parts.join("/");
}

// Turns what the settings page stores (a path, "~/..." or a file:// URL from
// a folder dialog) into a plain absolute path without a trailing slash.
function localPath(input, home) {
    let path = String(input || "").trim();
    if (path.indexOf("file://") === 0) {
        try {
            path = decodeURIComponent(path.substring("file://".length));
        } catch (e) {
            return "";
        }
    }
    if ((path === "~" || path.indexOf("~/") === 0) && home) {
        path = home + path.substring(1);
    }
    if (path.charAt(0) !== "/") {
        return "";
    }
    return joinPath(path);
}

// Obsidian identifies a vault by its folder name.
function vaultName(vaultPath) {
    const parts = joinPath(vaultPath).split("/");
    return parts[parts.length - 1];
}

// Vault-relative path of a note: folder + formatted name + ".md", like
// Obsidian's getNotePath().
function notePath(folder, formattedName) {
    let name = String(formattedName);
    if (name.slice(-3) !== ".md") {
        name += ".md";
    }
    return joinPath(folder, name);
}

// How deep under the notes folder a format can put files, e.g. 1 for
// "YYYY-MM-DD" and 3 for "YYYY/MM/YYYY-MM-DD". Names never contain "/",
// so a sample date shows the depth.
function searchDepth(format) {
    const sample = DateFormat.format({ y: 2000, m: 1, d: 1 }, format, Locales.EN);
    return sample.split("/").filter(function (s) { return s !== ""; }).length || 1;
}

// Prints the existing ones of `files` (paths relative to the vault's
// .obsidian folder) as "name\0contents\0" pairs.
function configCommand(vaultPath, files) {
    const vault = shellQuote(vaultPath);
    if (vault === null) {
        return null;
    }
    const quoted = [];
    for (let i = 0; i < files.length; i++) {
        const q = shellQuote(files[i]);
        if (q === null) {
            return null;
        }
        quoted.push(q);
    }
    return "cd -- " + vault + " 2>/dev/null || exit " + EXIT_NO_VAULT + "; "
        + "[ -d .obsidian ] || exit " + EXIT_NOT_A_VAULT + "; "
        + "for f in " + quoted.join(" ") + "; do "
        + "if [ -f \".obsidian/$f\" ]; then printf '%s\\0' \"$f\"; cat -- \".obsidian/$f\" | tr -d '\\000'; printf '\\0'; fi; "
        + "done; exit 0";
}

// Parses configCommand() output into { "daily-notes.json": "...", ... }.
// Files that don't exist are absent.
function parseConfigOutput(text) {
    return parsePairs(text);
}

// Lists Markdown files under `folderPath` up to `depth` levels deep as
// "size mtime relative/path\0" records.
function listCommand(folderPath, depth) {
    const folder = shellQuote(folderPath);
    const maxDepth = Math.max(1, Math.min(8, Math.floor(depth) || 1));
    if (folder === null) {
        return null;
    }
    return "cd -- " + folder + " 2>/dev/null || exit " + EXIT_NO_FOLDER + "; "
        + "find -L . -mindepth 1 -maxdepth " + maxDepth + " -type f -name '*.md' -printf '%s %T@ %P\\0'";
}

// Parses listCommand() output into { "relative/path.md": { size, mtime } },
// where mtime is in seconds.
function parseListOutput(text) {
    const files = {};
    const records = String(text).split("\0");
    for (let i = 0; i < records.length; i++) {
        const match = /^(\d+) (\d+(?:\.\d+)?) ([\s\S]+)$/.exec(records[i]);
        if (match) {
            files[match[3]] = { size: Number(match[1]), mtime: Number(match[2]) };
        }
    }
    return files;
}

// Prints the start of each file (relative to `folderPath`) as
// "path\0contents\0" pairs. Unreadable files come back empty.
function readCommand(folderPath, relativePaths) {
    const folder = shellQuote(folderPath);
    if (folder === null || relativePaths.length === 0) {
        return null;
    }
    const quoted = [];
    for (let i = 0; i < relativePaths.length; i++) {
        const q = shellQuote(relativePaths[i]);
        if (q === null) {
            return null;
        }
        quoted.push(q);
    }
    return "cd -- " + folder + " 2>/dev/null || exit " + EXIT_NO_FOLDER + "; "
        + "for f in " + quoted.join(" ") + "; do "
        + "printf '%s\\0' \"$f\"; head -c " + READ_LIMIT_BYTES + " -- \"$f\" 2>/dev/null | tr -d '\\000'; printf '\\0'; "
        + "done";
}

// Parses readCommand() output into { "relative/path.md": "contents" }.
function parseReadOutput(text) {
    return parsePairs(text);
}

// "name\0value\0name\0value\0" -> { name: value }
function parsePairs(text) {
    const result = {};
    const fields = String(text).split("\0");
    for (let i = 0; i + 1 < fields.length; i += 2) {
        result[fields[i]] = fields[i + 1];
    }
    return result;
}

// Obsidian wants every reserved character percent-encoded, including "/"
// (%2F) and spaces (%20); encodeURIComponent does exactly that.
function openUri(absolutePath) {
    return "obsidian://open?path=" + encodeURIComponent(absolutePath);
}

// Opens today's note, creating it from the template if needed. Requires the
// core Daily notes plugin.
function dailyUri(name) {
    return "obsidian://daily?vault=" + encodeURIComponent(name);
}

// Creates a note at a vault-relative path. Obsidian doesn't apply the daily
// note template to notes created this way.
function newUri(name, relativePath) {
    return "obsidian://new?vault=" + encodeURIComponent(name) + "&file=" + encodeURIComponent(relativePath);
}
