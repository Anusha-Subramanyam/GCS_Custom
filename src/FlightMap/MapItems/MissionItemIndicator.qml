/*=====================================================================

QGroundControl Open Source Ground Control Station

(c) 2009, 2015 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>

This file is part of the QGROUNDCONTROL project

    QGROUNDCONTROL is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    QGROUNDCONTROL is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with QGROUNDCONTROL. If not, see <http://www.gnu.org/licenses/>.

======================================================================*/

import QtQuick      2.4
import QtLocation   5.3

import QGroundControl.ScreenTools   1.0
import QGroundControl.Controls      1.0
import QGroundControl.Vehicle       1.0

/// Marker for displaying a mission item on the map
MapQuickItem {
    id: _item

    property var missionItem

    signal clicked

    anchorPoint.x:  sourceItem.width  / 2
    anchorPoint.y:  sourceItem.height / 2

    Connections {
        target: missionItem

        onCoordinateChanged:        recalcLabel()
        onRelativeAltitudeChanged:  recalcLabel()
    }

    Component.onCompleted: recalcLabel()

    function recalcLabel() {
        var label = Math.round(object.coordinate.altitude)
        if (!object.relativeAltitude) {
            label = "=" + label
        }
        if (object.homePosition) {
            label = "H" + label
        }
        _label.label = label
    }

    sourceItem:
        MissionItemIndexLabel {
            id:             _label
            isCurrentItem:  missionItem.isCurrentItem
            onClicked:      _item.clicked()
        }
}
