/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


import QtQuick                      2.3
import QtQuick.Controls             1.2
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

import QGroundControl               1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.Airspace      1.0
import QGroundControl.Controllers   1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FlightDisplay 1.0
import QGroundControl.FlightMap     1.0
import QGroundControl.Vehicle       1.0



Item {
    id: pip

    property bool isHidden:  false
    property bool isDark:    false

    // As a percentage of the window width
    property real maxSize: 0.75
    property real minSize: 0.10

    property bool inPopup: false
    property bool enablePopup: true

    property var _videoSettings: QGroundControl.settingsManager.videoSettings

    property var    _videoReceiver: QGroundControl.videoManager.videoReceiver
    property bool   _recordingVideo: _videoReceiver && _videoReceiver.recording
    property bool   _videoRunning: _videoReceiver && _videoReceiver.videoRunning
    property bool   _streamingEnabled: QGroundControl.settingsManager.videoSettings.streamConfigured
    property var    _dynamicCameras: activeVehicle ? activeVehicle.dynamicCameras : null
    property int    _curCameraIndex: _dynamicCameras ? _dynamicCameras.currentCamera : 0
    property var    _currentCamera: _dynamicCameras? _dynamicCameras.cameras.get(_curCameraIndex) : null
    property var    _camera: _currentCamera && _currentCamera.paramComplete ?_currentCamera : null

    signal  activated()
    signal  hideIt(bool state)
    signal  newWidth(real newWidth)
    signal  popup()

    MouseArea {
        id: pipMouseArea
        anchors.fill: parent
        enabled:      !isHidden
        hoverEnabled: true
        onClicked: {
            pip.activated()
        }
    }

    // MouseArea to drag in order to resize the PiP area
    MouseArea {
        id: pipResize
        anchors.top: parent.top
        anchors.right: parent.right
        height: ScreenTools.minTouchPixels
        width: height
        property real initialX: 0
        property real initialWidth: 0

        onClicked: {
            // TODO propagate
        }

        // When we push the mouse button down, we un-anchor the mouse area to prevent a resizing loop
        onPressed: {
            pipResize.anchors.top = undefined // Top doesn't seem to 'detach'
            pipResize.anchors.right = undefined // This one works right, which is what we really need
            pipResize.initialX = mouse.x
            pipResize.initialWidth = pip.width
        }

        // When we let go of the mouse button, we re-anchor the mouse area in the correct position
        onReleased: {
            pipResize.anchors.top = pip.top
            pipResize.anchors.right = pip.right
        }

        // Drag
        onPositionChanged: {
            if (pipResize.pressed) {
                var parentW = pip.parent.width // flightView
                var newW = pipResize.initialWidth + mouse.x - pipResize.initialX
                if (newW < parentW * maxSize && newW > parentW * minSize) {
                    newWidth(newW)
                }
            }
        }
    }

    // Resize icon
    Image {
        source:         "/qmlimages/pipResize.svg"
        fillMode:       Image.PreserveAspectFit
        mipmap: true
        anchors.right:  parent.right
        anchors.top:    parent.top
        visible:        !isHidden && (ScreenTools.isMobile || pipMouseArea.containsMouse) && !inPopup
        height:         ScreenTools.defaultFontPixelHeight * 2.5
        width:          ScreenTools.defaultFontPixelHeight * 2.5
        sourceSize.height:  height
    }

    // Resize pip window if necessary when main window is resized
    property int pipLock: 2

    Connections {
        target: pip.parent
        onWidthChanged: {
            // hackity hack...
            // don't fire this while app is loading/initializing (it happens twice)
            if (pipLock) {
                pipLock--
                return
            }

            var parentW = pip.parent.width

            if (pip.width > parentW * maxSize) {
                newWidth(parentW * maxSize)
            } else if (pip.width < parentW * minSize) {
                newWidth(parentW * minSize)
            }
        }
    }

     //-- PIP Popup Indicator
    Image {
        id:             popupPIP
        source:         "/qmlimages/PiP.svg"
        mipmap:         true
        fillMode:       Image.PreserveAspectFit
        anchors.left:   parent.left
        anchors.top:    parent.top
        visible:        !isHidden && !inPopup && !ScreenTools.isMobile && enablePopup && pipMouseArea.containsMouse
        height:         ScreenTools.defaultFontPixelHeight * 2.5
        width:          ScreenTools.defaultFontPixelHeight * 2.5
        sourceSize.height:  height
        MouseArea {
            anchors.fill: parent
            onClicked: {
                inPopup = true
                pip.popup()
            }
        }
    }

    //-- PIP Corner Indicator
    Image {
        id:             closePIP
        source:         "/qmlimages/pipHide.svg"
        mipmap:         true
        fillMode:       Image.PreserveAspectFit
        anchors.left:   parent.left
        anchors.bottom: parent.bottom
        visible:        !isHidden && (ScreenTools.isMobile || pipMouseArea.containsMouse)
        height:         ScreenTools.defaultFontPixelHeight * 2.5
        width:          ScreenTools.defaultFontPixelHeight * 2.5
        sourceSize.height:  height
        MouseArea {
            anchors.fill: parent
            onClicked: {
                pip.hideIt(true)
            }
        }
    }

    //-- Show PIP
    Rectangle {
        id:                     openPIP
        anchors.left :          parent.left
        anchors.bottom:         parent.bottom
        height:                 ScreenTools.defaultFontPixelHeight * 2
        width:                  ScreenTools.defaultFontPixelHeight * 2
        radius:                 ScreenTools.defaultFontPixelHeight / 3
        visible:                isHidden
        color:                  isDark ? Qt.rgba(0,0,0,0.75) : Qt.rgba(0,0,0,0.5)
        Image {
            width:              parent.width  * 0.75
            height:             parent.height * 0.75
            sourceSize.height:  height
            source:             "/res/buttonRight.svg"
            mipmap:             true
            fillMode:           Image.PreserveAspectFit
            anchors.verticalCenter:     parent.verticalCenter
            anchors.horizontalCenter:   parent.horizontalCenter
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                pip.hideIt(false)
            }
        }
    }

    RowLayout {
        width: parent.width
        y: parent.height - height
        visible:        !isHidden && (ScreenTools.isMobile || pipMouseArea.containsMouse)

        Item {
            Layout.fillWidth: true
        }

        QGCImageButton {
            id: playPause
            checkState: _videoSettings.streamEnabled.rawValue
            imageOff: "/res/Stop"
            imageOn: "/res/Play"
            onClicked: {
                if(!_videoSettings.streamEnabled.rawValue) {
                    _videoReceiver.start();
                } else {
                    _videoReceiver.stop();
                }
                _videoSettings.streamEnabled.rawValue = !_videoSettings.streamEnabled.rawValue;
            }
        }

        QGCImageButton {
            id: gridLines
            checkState: _videoSettings.gridLines.rawValue
            imageOff: "/res/takeoff.svg"
            imageOn:"/res/wind-rose.svg"
            enabled: _streamingEnabled && activeVehicle
            visible: QGroundControl.videoManager.isGStreamer && _videoSettings.gridLines.visible
            onClicked: {
                _videoSettings.gridLines.rawValue = !_videoSettings.gridLines.rawValue
            }
        }

        // Button to start/stop video recording
        QGCImageButton {
            id: recordVideo
            checkState: _recordingVideo
            imageOff: "/res/wind-rose.svg"
            imageOn: "/res/wind-rose.svg"
            enabled: _videoSettings.streamEnabled.rawValue
            onClicked: {
                if (_recordingVideo) {
                    _videoReceiver.stopRecording()
                } else {
                    _videoReceiver.startRecording(videoFileName.text)
                }
            }
        }

        //-- Configure VideoReceiver
        QGCImageButton {
            id: configureVideo
            source: "/qmlimages/Gears.svg"
            onClicked: {
                popup.open()
            }
            Popup {
                id: popup
                parent: Overlay.overlay
                modal: true
                focus: true
                x: Math.round((parent.width - width) / 2)
                y: Math.round((parent.height - height) / 2)
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                contentItem: VideoSettings {
                }
            }
        }
        Item {
            Layout.fillWidth: true
        }
    }
}
