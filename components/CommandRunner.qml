import Quickshell.Io
import QtQuick

Process {
    id: root

    property string output: ""
    property var onDone: null

    stdout: SplitParser {
        onRead: data => { root.output += data; }
    }

    onRunningChanged: {
        if (!running && root.onDone) {
            const callback = root.onDone;
            root.onDone = null;
            callback(root.output);
        }
    }
}
