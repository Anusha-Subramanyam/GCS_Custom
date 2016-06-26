/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


#include "ParameterLoaderTest.h"
#include "MultiVehicleManager.h"
#include "QGCApplication.h"
#include "ParameterLoader.h"

/// Test failure modes which should still lead to param load success
void ParameterLoaderTest::_noFailureWorker(MockConfiguration::FailureMode_t failureMode)
{
    Q_ASSERT(!_mockLink);
    MultiVehicleManager* vehicleMgr = qgcApp()->toolbox()->multiVehicleManager();
    QVERIFY(vehicleMgr);
    QSignalSpy spyVehicle(vehicleMgr, SIGNAL(activeVehicleAvailableChanged(bool)));

    _mockLink = MockLink::startPX4MockLink(false, failureMode);

    // Wait for the Vehicle to get created
    if (spyVehicle.count() == 0)
        QCOMPARE(spyVehicle.wait(5000), true);
    QCOMPARE(spyVehicle.count(), 1);
    QList<QVariant> arguments = spyVehicle.takeFirst();
    QCOMPARE(arguments.count(), 1);
    QCOMPARE(arguments.at(0).toBool(), true);

    Vehicle* vehicle = vehicleMgr->activeVehicle();
    QVERIFY(vehicle);
    QSignalSpy spyProgress(vehicle->getParameterLoader(), SIGNAL(parameterListProgress(float)));
    QSignalSpy spyParamsReady(vehicleMgr, SIGNAL(parameterReadyVehicleAvailableChanged(bool)));

    // We should get progress bar updates during load
    QCOMPARE(spyProgress.wait(2000), true);
    arguments = spyProgress.takeFirst();
    QCOMPARE(arguments.count(), 1);
    QVERIFY(arguments.at(0).toFloat() > 0.0f);

    // When param load is complete we get the param ready signal
    if (spyParamsReady.count() == 0)
        QCOMPARE(spyParamsReady.wait(60000), true);
    arguments = spyParamsReady.takeFirst();
    QCOMPARE(arguments.count(), 1);
    QCOMPARE(arguments.at(0).toBool(), true);

    // Progress should have been set back to 0
    arguments = spyProgress.takeLast();
    QCOMPARE(arguments.count(), 1);
    QCOMPARE(arguments.at(0).toFloat(), 0.0f);
}


void ParameterLoaderTest::_noFailure(void)
{
    _noFailureWorker(MockConfiguration::FailNone);
}

void ParameterLoaderTest::_requestListMissingParamSuccess(void)
{
    _noFailureWorker(MockConfiguration::FailMissingParamOnInitialReqest);
}

// Test no response to param_request_list
void ParameterLoaderTest::_requestListNoResponse(void)
{
    Q_ASSERT(!_mockLink);
    MultiVehicleManager* vehicleMgr = qgcApp()->toolbox()->multiVehicleManager();
    QVERIFY(vehicleMgr);

    QSignalSpy spyVehicle(vehicleMgr, SIGNAL(activeVehicleAvailableChanged(bool)));
    _mockLink = MockLink::startPX4MockLink(false, MockConfiguration::FailParamNoReponseToRequestList);

    // Wait for the Vehicle to get created
    if (spyVehicle.count() == 0)
        QCOMPARE(spyVehicle.wait(5000), true);

    QList<QVariant> arguments = spyVehicle.takeFirst();
    QCOMPARE(arguments.count(), 1);
    QCOMPARE(arguments.at(0).toBool(), true);

    Vehicle* vehicle = vehicleMgr->activeVehicle();
    QVERIFY(vehicle);

    QSignalSpy spyParamsReady(vehicleMgr, SIGNAL(parameterReadyVehicleAvailableChanged(bool)));
    QSignalSpy spyProgress(vehicle->getParameterLoader(), SIGNAL(parameterListProgress(float)));

    // We should not get any progress bar updates, nor a parameter ready signal
    QCOMPARE(spyProgress.wait(500), false);
    QCOMPARE(spyParamsReady.wait((ParameterLoader::_initialRequestTimeoutInterval*ParameterLoader::_maxInitialRequestListRetry) + 500), false);

    // User should have been notified
    checkMultipleExpectedMessageBox(ParameterLoader::_maxInitialRequestListRetry);
}

// MockLink will fail to send a param on initial request, it will also fail to send it on subsequent
// param_read requests.
void ParameterLoaderTest::_requestListMissingParamFail(void)
{
    // Will pop error about missing params
    setExpectedMessageBox(QMessageBox::Ok);
    MultiVehicleManager* vehicleMgr = qgcApp()->toolbox()->multiVehicleManager();
    QVERIFY(vehicleMgr);

    QSignalSpy spyVehicle(vehicleMgr, SIGNAL(activeVehicleAvailableChanged(bool)));

    Q_ASSERT(!_mockLink);
    _mockLink = MockLink::startPX4MockLink(false, MockConfiguration::FailMissingParamOnAllRequests);

    // Wait for the Vehicle to get created
    if (spyVehicle.count() == 0)
        QCOMPARE(spyVehicle.wait(5000), true);
    QCOMPARE(spyVehicle.count(), 1);
    QList<QVariant> arguments = spyVehicle.takeFirst();
    QCOMPARE(arguments.count(), 1);
    QCOMPARE(arguments.at(0).toBool(), true);

    Vehicle* vehicle = vehicleMgr->activeVehicle();
    QVERIFY(vehicle);

    QSignalSpy spyParamsReady(vehicleMgr, SIGNAL(parameterReadyVehicleAvailableChanged(bool)));
    QSignalSpy spyProgress(vehicle->getParameterLoader(), SIGNAL(parameterListProgress(float)));

    // We will get progress bar updates, since it will fail after getting partially through the request
    QCOMPARE(spyProgress.wait(2000), true);
    arguments = spyProgress.takeFirst();
    QCOMPARE(arguments.count(), 1);
    QVERIFY(arguments.at(0).toFloat() > 0.0f);

    // We should get a parameters ready signal, but Vehicle should indicate missing params
    if (spyParamsReady.count() == 0)
        QCOMPARE(spyParamsReady.wait(40000), true);
    QCOMPARE(vehicle->missingParameters(), true);

    // User should have been notified
    checkExpectedMessageBox();
}
