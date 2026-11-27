// OBS follows the WoW you are in (Nov 26). OBS's game layer (obs-vkcapture) films the game started last and can't
// tell two clients apart. With two or more WoWs open, clicking into one runs `obs-record follow <pid>`:
// with the patched obs-vkcapture (pc/obs-vkcapture-follow) the game layer films that WoW, in HDR; with the stock
// one, a WoW that isn't the filmed one gets the screen layer (SDR) until you leave it. Nothing runs with one WoW open.
// Way back: kwriteconfig6 --file kwinrc --group Plugins --key jackwowfollowEnabled false; qdbus6 org.kde.KWin /KWin reconfigure
function isWow(w) {
    return w && w.normalWindow && /^wow(classic)?\.exe$/i.test(w.resourceClass);
}
function wows(except) {
    return workspace.windowList().filter(function (o) { return o !== except && isWow(o); }).length;
}
function tell(arg) {
    callDBus("org.freedesktop.systemd1", "/org/freedesktop/systemd1", "org.freedesktop.systemd1.Manager",
             "StartUnit", "wow-follow@" + arg + ".service", "replace");
}
let told = false;  // the screen layer may be on: tell again when you leave WoW
workspace.windowActivated.connect(function (w) {
    if (isWow(w) && wows(null) >= 2) {
        tell(String(w.pid));
        told = true;
    } else if (told && w && !isWow(w)) {
        tell("0");
        told = false;
    }
});
workspace.windowRemoved.connect(function (w) {
    if (!told || !isWow(w)) return;
    const a = workspace.activeWindow;
    tell((isWow(a) && a !== w ? a.pid : 0) + "_late");
    if (wows(w) < 2) told = false;
});
