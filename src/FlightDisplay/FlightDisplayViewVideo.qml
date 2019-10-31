/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


import QtQuick                          2.11
import QtQuick.Controls                 2.4

import QGroundControl                   1.0
import QGroundControl.FlightDisplay     1.0
import QGroundControl.FlightMap         1.0
import QGroundControl.ScreenTools       1.0
import QGroundControl.Controls          1.0
import QGroundControl.Palette           1.0
import QGroundControl.Vehicle           1.0
import QGroundControl.Controllers       1.0
import QGroundControl.QgcQtGStreamer    1.0
import QGroundControl.SettingsManager       1.0

Item {
    id:     root
    clip:   true
    property double _ar:                QGroundControl.videoManager.aspectRatio
    property bool   _showGrid:          QGroundControl.settingsManager.videoSettings.gridLines.rawValue > 0
    property var    _videoReceiver:     QGroundControl.videoManager.videoReceiver
    property var    _dynamicCameras:    activeVehicle ? activeVehicle.dynamicCameras : null
    property bool   _connected:         activeVehicle ? !activeVehicle.connectionLost : false
    property int    _curCameraIndex:    _dynamicCameras ? _dynamicCameras.currentCamera : 0
    property bool   _isCamera:          _dynamicCameras ? _dynamicCameras.cameras.count > 0 : false
    property var    _camera:            _isCamera ? _dynamicCameras.cameras.get(_curCameraIndex) : null
    property bool   _hasZoom:           _camera && _camera.hasZoom
    property int    _fitMode:           QGroundControl.settingsManager.videoSettings.videoFit.rawValue

    property alias videoReceiver: videoSurface.videoReceiver

    property double _thermalHeightFactor: 0.85 //-- TODO

    /*
    Rectangle {
        id:             noVideo
        anchors.fill:   parent
        color:          Qt.rgba(0,0,0,0.75)
        visible:  false // TODO: Restore-me     !(_videoReceiver && _videoReceiver.videoRunning)
        QGCLabel {
            text:               QGroundControl.settingsManager.videoSettings.streamEnabled.rawValue ? qsTr("WAITING FOR VIDEO") : qsTr("VIDEO DISABLED")
            font.family:        ScreenTools.demiboldFontFamily
            color:              "white"
            font.pointSize:     mainIsMap ? ScreenTools.smallFontPointSize : ScreenTools.largeFontPointSize
            anchors.centerIn:   parent
        }
        MouseArea {
            anchors.fill: parent
            onDoubleClicked: {
                QGroundControl.videoManager.fullScreen = !QGroundControl.videoManager.fullScreen
            }
        }
    }
    */

    Rectangle {
        anchors.fill:   parent
        color:          "black"
        visible:    true  //    _videoReceiver && _videoReceiver.videoRunning
        function getWidth() {
            //-- Fit Width or Stretch
            if(_fitMode === 0 || _fitMode === 2) {
                return parent.width
            }
            //-- Fit Height
            return _ar != 0.0 ? parent.height * _ar : parent.width
        }
        function getHeight() {
            //-- Fit Height or Stretch
            if(_fitMode === 1 || _fitMode === 2) {
                return parent.height
            }
            //-- Fit Width
            return _ar != 0.0 ? parent.width * (1 / _ar) : parent.height
        }

        VideoSettingsController {
            visible: false
        }

        //-- Main Video
        VideoSurface {
            id: videoSurface
            videoItem: videoContent
        }

        QGCVideoBackground {
            id:             videoContent
            height:         parent.getHeight()
            width:          parent.getWidth()
            anchors.centerIn: parent
            visible: true //       _videoReceiver && _videoReceiver.videoRunning && !(QGroundControl.videoManager.hasThermal && _camera.thermalMode === QGCCameraControl.THERMAL_FULL)

            // TODO: Restore
            /*
            Connections {
                target:         _videoReceiver
                onImageFileChanged: {
                    videoContent.grabToImage(function(result) {
                        if (!result.saveToFile(_videoReceiver.imageFile)) {
                            console.error('Error capturing video frame');
                        }
                    });
                }
            }
            */
        }

        //-- Thermal Image
        /*
        Item {
            id:                 thermalItem
            width:              height * QGroundControl.videoManager.thermalAspectRatio
            height:             _camera ? (_camera.thermalMode === QGCCameraControl.THERMAL_FULL ? parent.height : (_camera.thermalMode === QGCCameraControl.THERMAL_PIP ? ScreenTools.defaultFontPixelHeight * 12 : parent.height * _thermalHeightFactor)) : 0
            anchors.centerIn:   parent
            visible:        false //   QGroundControl.videoManager.hasThermal && _camera.thermalMode !== QGCCameraControl.THERMAL_OFF
            function pipOrNot() {
                if(_camera) {
                    if(_camera.thermalMode === QGCCameraControl.THERMAL_PIP) {
                        anchors.centerIn    = undefined
                        anchors.top         = parent.top
                        anchors.topMargin   = mainWindow.header.height + (ScreenTools.defaultFontPixelHeight * 0.5)
                        anchors.left        = parent.left
                        anchors.leftMargin  = ScreenTools.defaultFontPixelWidth * 12
                    } else {
                        anchors.top         = undefined
                        anchors.topMargin   = undefined
                        anchors.left        = undefined
                        anchors.leftMargin  = undefined
                        anchors.centerIn    = parent
                    }
                }
            }
            Connections {
                target:                 _camera
                onThermalModeChanged:   thermalItem.pipOrNot()
            }
            onVisibleChanged: {
                thermalItem.pipOrNot()
            }
            QGCVideoBackground {
                id:             thermalVideo
                anchors.fill:   parent
                receiver:       QGroundControl.videoManager.thermalVideoReceiver
                display:        QGroundControl.videoManager.thermalVideoReceiver ? QGroundControl.videoManager.thermalVideoReceiver.videoSurface : null
                opacity:        _camera ? (_camera.thermalMode === QGCCameraControl.THERMAL_BLEND ? _camera.thermalOpacity / 100 : 1.0) : 0
            }

        }
        */

        //-- Full screen toggle
        MouseArea {
            anchors.fill: parent
            onDoubleClicked: {
                QGroundControl.videoManager.fullScreen = !QGroundControl.videoManager.fullScreen
            }
        }
        //-- Zoom
        PinchArea {
            id:             pinchZoom
            enabled:        _hasZoom
            anchors.fill:   parent
            onPinchStarted: pinchZoom.zoom = 0
            onPinchUpdated: {
                if(_hasZoom) {
                    var z = 0
                    if(pinch.scale < 1) {
                        z = Math.round(pinch.scale * -10)
                    } else {
                        z = Math.round(pinch.scale)
                    }
                    if(pinchZoom.zoom != z) {
                        _camera.stepZoom(z)
                    }
                }
            }
            property int zoom: 0
        }
    }

    QGCPipable {
        id:                 _flightVideoPipControl
        z:                  _flightVideo.z + 3
        anchors.fill:       parent
        visible:            true // QGroundControl.videoManager.hasVideo && !QGroundControl.videoManager.fullScreen && _flightVideo.state != "popup"
        isDark:        isBackgroundDark
        enablePopup:   mainIsMap
        onActivated: {
            mainIsMap = !mainIsMap
            setStates()
        }
        onHideIt: {
            setPipVisibility(!state)
        }
        onPopup: {
            videoWindow.visible = true
            _flightVideo.state = "popup"
        }
        onNewWidth: {
            _pipSize = newWidth
        }
    }

    /*
    onParentChanged: {
        // If video comes back from popup
        // correct anchors.
        // Such thing is not possible with ParentChange.
        if(parent == _mapAndVideo) {
            // Do anchors again after popup
            anchors.left =       _mapAndVideo.left
            anchors.bottom =     _mapAndVideo.bottom
            anchors.margins =    ScreenTools.defaultFontPixelHeight
        }
    }
    */

    states: [
        State {
            name:   "pipMode"
            PropertyChanges {
                target: _flightVideo
                anchors.margins: ScreenTools.defaultFontPixelHeight
            }
            PropertyChanges {
                target: _flightVideoPipControl
                inPopup: false
            }
        },
        State {
            name:   "fullMode"
            PropertyChanges {
                target: _flightVideo
                anchors.margins:    0
            }
            PropertyChanges {
                target: _flightVideoPipControl
                inPopup: false
            }
        },
        State {
            name: "popup"
            StateChangeScript {
                script: {
                    // Stop video, restart it again with Timer
                    // Avoiding crashs if ParentChange is not yet done
                    QGroundControl.videoManager.stopVideo()
                    videoPopUpTimer.running = true
                }
            }
            PropertyChanges {
                target: _flightVideoPipControl
                inPopup: true
            }
        },
        State {
            name: "popup-finished"
            ParentChange {
                target: _flightVideo
                parent: videoItem
                x: 0
                y: 0
                width: videoItem.width
                height: videoItem.height
            }
        },
        State {
            name: "unpopup"
            StateChangeScript {
                script: {
                    QGroundControl.videoManager.stopVideo()
                    videoPopUpTimer.running = true
                }
            }
            ParentChange {
                target: _flightVideo
                parent: _mapAndVideo
            }
            PropertyChanges {
                target: _flightVideoPipControl
                inPopup: false
            }
        }
    ]

}
