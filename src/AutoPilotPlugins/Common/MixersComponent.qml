/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick              2.5
import QtQuick.Controls     1.4

import QGroundControl               1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controllers   1.0


// Mixer Tuning setup page
SetupPage {
    id:             tuningPage
    pageComponent:  tuningPageComponent

    property int    _rowHeight:         ScreenTools.defaultFontPixelHeight * 2
    property int    _rowWidth:          10      // Dynamic adjusted at runtime

    Component {
        id: tuningPageComponent

        Column {
            width:      availableWidth
            spacing:    _margins

            FactPanelController { id: controller; factPanel: tuningPage.viewPanel }

            MixersComponentController {
                id:         mixers
                factPanel:  tuningPage.viewPanel
            }

            QGCPalette { id: palette; colorGroupEnabled: true }

            QGCLabel { text: qsTr("Group") }

            QGCTextField {
                id:                 groupText
                text:               "0"
            }

            QGCButton {
                id:getMixersCountButton
                text: qsTr("Request mixer count")
                onClicked: {
                    mixers.getMixersCountButtonClicked()
                }
            }

            QGCButton {
                id:requestAllButton
                text: qsTr("Request all")
                onClicked: {
                    mixers.requestAllButtonClicked()
                }
            }

            QGCButton {
                id:requestMissing
                text: qsTr("Request missing")
                onClicked: {
                    mixers.requestMissingButtonClicked()
                }
            }

            /// Parameter list
            QGCListView {
                id:                 mixerListView
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                anchors.left:       parent.left
                anchors.right:      parent.right
                anchors.top:        parent.verticalCenter
                anchors.bottom:     parent.bottom
                orientation:        ListView.Vertical
                model:              controller.mixers
                cacheBuffer:        height > 0 ? height * 2 : 0
                clip:               true

                delegate: Rectangle {
                    height: _rowHeight
                    width:  _rowWidth
                    color:  Qt.rgba(0,0,0,0)

                    Row {
                        id:     factRow
                        spacing: Math.ceil(ScreenTools.defaultFontPixelWidth * 0.5)
                        anchors.verticalCenter: parent.verticalCenter

                        property Fact modelFact: object

                        QGCLabel {
                            id:     mixerInputLabel
                            width:  ScreenTools.defaultFontPixelWidth  * 20
                            text:   "Mixer Input Label"
                            clip:   true
                        }

                        QGCLabel {
                            id:     mixerNameLabel
                            width:  ScreenTools.defaultFontPixelWidth  * 20
                            text:   "Mixer Name Label"
                            clip:   true
                        }

                        QGCLabel {
                            id:     mixerIDLabel
                            width:  ScreenTools.defaultFontPixelWidth  * 10
                            text:   "Mixer ID"
                            clip:   true
                        }

                        QGCLabel {
                            id:     mixerOutputLabel
                            width:  ScreenTools.defaultFontPixelWidth  * 20
                            text:   "Mixer Output Label"
                            clip:   true
                        }

//                        QGCLabel {
//                            id:     mixerInputLabel
//                            width:  ScreenTools.defaultFontPixelWidth  * 20
//                            text:   factRow.modelFact.name
//                            clip:   true
//                        }

//                        QGCLabel {
//                            id:     mixerNameLabel
//                            width:  ScreenTools.defaultFontPixelWidth  * 20
//                            color:  factRow.modelFact.defaultValueAvailable ? (factRow.modelFact.valueEqualsDefault ? __qgcPal.text : __qgcPal.warningText) : __qgcPal.text
//                            text:   factRow.modelFact.valueString + " " + factRow.modelFact.units
//                            clip:   true
//                        }

//                        QGCLabel {
//                            id:     mixerIDLabel
//                            width:  ScreenTools.defaultFontPixelWidth  * 20
//                            color:  factRow.modelFact.defaultValueAvailable ? (factRow.modelFact.valueEqualsDefault ? __qgcPal.text : __qgcPal.warningText) : __qgcPal.text
//                            text:   factRow.modelFact.valueString + " " + factRow.modelFact.units
//                            clip:   true
//                        }

//                        QGCLabel {
//                            id:     mixerOutputLabel
//                            width:  ScreenTools.defaultFontPixelWidth  * 20
//                            color:  factRow.modelFact.defaultValueAvailable ? (factRow.modelFact.valueEqualsDefault ? __qgcPal.text : __qgcPal.warningText) : __qgcPal.text
//                            text:   factRow.modelFact.valueString + " " + factRow.modelFact.units
//                            clip:   true
//                        }

//                        Component.onCompleted: {
//                            if(_rowWidth < factRow.width + ScreenTools.defaultFontPixelWidth) {
//                                _rowWidth = factRow.width + ScreenTools.defaultFontPixelWidth
//                            }
//                        }
                    }

                    Rectangle {
                        width:  _rowWidth
                        height: 1
                        color:  __qgcPal.text
                        opacity: 0.15
                        anchors.bottom: parent.bottom
                        anchors.left:   parent.left
                    }

                    MouseArea {
                        anchors.fill:       parent
                        acceptedButtons:    Qt.LeftButton
                        onClicked: {
                            _editorDialogFact = factRow.modelFact
//                            showDialog(editorDialogComponent, qsTr("Mixer Editor"), qgcView.showDialogDefaultWidth, StandardButton.Cancel | StandardButton.Save)
                        }
                    }
                }
            }
        } // Column
    } // Component
} // SetupView
