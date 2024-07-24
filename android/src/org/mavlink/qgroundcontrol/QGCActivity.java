package org.mavlink.qgroundcontrol;

import java.io.IOException;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;
import java.util.HashMap;
import java.util.List;
import java.util.Timer;
import java.util.EnumSet;
import java.util.TimerTask;

import android.app.Activity;
import android.app.PendingIntent;
import android.bluetooth.BluetoothDevice;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbDeviceConnection;
import android.hardware.usb.UsbManager;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.os.PowerManager;
import android.os.storage.StorageManager;
import android.os.storage.StorageVolume;
import android.util.Log;
import android.view.WindowManager;

import com.hoho.android.usbserial.driver.UsbSerialDriver;
import com.hoho.android.usbserial.driver.UsbSerialPort;
import com.hoho.android.usbserial.driver.UsbSerialProber;
import com.hoho.android.usbserial.driver.SerialTimeoutException;
import com.hoho.android.usbserial.driver.*;
import com.hoho.android.usbserial.util.UsbUtils;
import com.hoho.android.usbserial.util.HexDump;
import com.hoho.android.usbserial.util.MonotonicClock;

import org.mavlink.qgroundcontrol.SerialInputOutputManager;
import org.mavlink.qgroundcontrol.QGCProber;

import org.qtproject.qt.android.bindings.QtActivity;
import org.qtproject.qt.android.QtNative;

public class QGCActivity extends QtActivity
{
    private static final int BAD_DEVICE_ID = 0;
    private static final String TAG = "QGC_QGCActivity";
    private static final String ACTION_USB_PERMISSION = "org.mavlink.qgroundcontrol.action.USB_PERMISSION";

    private static final String SCREEN_BRIGHT_WAKE_LOCK_TAG = "QGroundControl";
    private static final String MULTICAST_LOCK_TAG = "QGroundControl";

    private static QGCActivity _instance = null;
    private static Context m_context;

    private static PendingIntent _usbPermissionIntent = null;
    private static UsbManager _usbManager = null;
    private static List<UsbSerialDriver> _drivers;
    private static HashMap<Integer, SerialInputOutputManager> _serialIoManager;
    private static HashMap<Integer, Long> _userDataHashByDeviceId;

    private static PowerManager.WakeLock _wakeLock;
    private static WifiManager.MulticastLock _wifiMulticastLock;

    private final static ExecutorService m_Executor = Executors.newSingleThreadExecutor();

    private final static SerialInputOutputManager.Listener m_Listener = new SerialInputOutputManager.Listener() {
        @Override
        public void onRunError(Exception e, long userData)
        {
            Log.e(TAG, "onRunError Exception", e);
            nativeDeviceException(userData, e.getMessage());
        }

        @Override
        public void onNewData(final byte[] data, long userData)
        {
            nativeDeviceNewData(userData, data);
        }
    };

    private final static BroadcastReceiver _usbReceiver = new BroadcastReceiver() {
        public void onReceive(Context context, Intent intent)
        {
            final String action = intent.getAction();
            Log.i(TAG, "BroadcastReceiver USB action " + action);

            if (ACTION_USB_PERMISSION.equals(action)) {
                handleUsbPermission(intent);
            } else if (UsbManager.ACTION_USB_DEVICE_DETACHED.equals(action)) {
                handleUsbDeviceDetached(intent);
            } else if (UsbManager.ACTION_USB_DEVICE_ATTACHED.equals(action)) {
                handleUsbDeviceAttached(intent);
            }

            try {
               nativeUpdateAvailableJoysticks();
            } catch (final Exception e) {
               Log.e(TAG, "Exception nativeUpdateAvailableJoysticks()", e);
            }
        }
    };

    private static void handleUsbPermission(final Intent intent)
    {
        synchronized (_instance) {
            final UsbDevice device = (UsbDevice)intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
            if (device != null) {
                final UsbSerialDriver driver = _findDriverByDeviceId(device.getDeviceId());

                if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                    qgcLogDebug("Permission granted to " + device.getDeviceName());
                    try {
                        driver.getPorts().get(0).open(_usbManager.openDevice(device));
                    } catch (final IOException e) {
                        Log.e(TAG, "Error opening port", e);
                    }
                } else {
                    qgcLogDebug("Permission denied for " + device.getDeviceName());
                }
            }
        }
    }

    private static void handleUsbDeviceDetached(final Intent intent)
    {
        final UsbDevice device = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
        if (device != null) {
            if (_userDataHashByDeviceId.containsKey(device.getDeviceId())) {
                nativeDeviceHasDisconnected(_userDataHashByDeviceId.get(device.getDeviceId()));
            }
        }
    }

    private static void handleUsbDeviceAttached(final Intent intent)
    {
        final UsbDevice device = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
        if (device != null) {
            final UsbSerialDriver driver = _findDriverByDeviceId(device.getDeviceId());
            if (driver != null && !_usbManager.hasPermission(device)) {
                qgcLogDebug("Requesting permission for device " + device.getDeviceName());
                _usbManager.requestPermission(device, _usbPermissionIntent);
            }
        }
    }

    // Native C++ functions which connect back to QSerialPort code
    private static native void nativeDeviceHasDisconnected(final long userData);
    private static native void nativeDeviceException(final long userData, final String message);
    private static native void nativeDeviceNewData(final long userData, final byte[] data);
    private static native void nativeUpdateAvailableJoysticks();

    // Native C++ functions called to log output
    public static native void qgcLogDebug(final String message);
    public static native void qgcLogWarning(final String message);

    public native void nativeInit();

    // QGCActivity singleton
    public QGCActivity()
    {
        _instance = this;
        _drivers = new ArrayList<>();
        _userDataHashByDeviceId = new HashMap<>();
        _serialIoManager = new HashMap<>();
    }

    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);

        nativeInit();
        acquireWakeLock();
        keepScreenOn();
        setupMulticastLock();
        registerReceivers();
        setupUsbPermissionIntent();

        _usbManager = (UsbManager) _instance.getSystemService(Context.USB_SERVICE);
    }

    private void acquireWakeLock()
    {
        final PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
        _wakeLock = pm.newWakeLock(PowerManager.SCREEN_BRIGHT_WAKE_LOCK, SCREEN_BRIGHT_WAKE_LOCK_TAG);
        if (_wakeLock != null) {
            _wakeLock.acquire();
        } else {
            Log.i(TAG, "SCREEN_BRIGHT_WAKE_LOCK not acquired!!!");
        }
    }

    private void keepScreenOn()
    {
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    }

    // Workaround for QTBUG-73138
    private void setupMulticastLock()
    {
        if (_wifiMulticastLock == null) {
            final WifiManager wifi = (WifiManager)getSystemService(Context.WIFI_SERVICE);
            _wifiMulticastLock = wifi.createMulticastLock(MULTICAST_LOCK_TAG);
            _wifiMulticastLock.setReferenceCounted(true);
        }

        _wifiMulticastLock.acquire();
        Log.d(TAG, "Multicast lock: " + _wifiMulticastLock.toString());
    }

    private void registerReceivers()
    {
        final IntentFilter filter = new IntentFilter();
        filter.addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED);
        filter.addAction(UsbManager.ACTION_USB_DEVICE_DETACHED);
        filter.addAction(ACTION_USB_PERMISSION);
        filter.addAction(BluetoothDevice.ACTION_ACL_CONNECTED);
        filter.addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED);
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(_usbReceiver, filter, RECEIVER_EXPORTED);
        } else {
            registerReceiver(_usbReceiver, filter);
        }
    }

    private void setupUsbPermissionIntent()
    {
        int intentFlags = 0;
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            intentFlags = PendingIntent.FLAG_IMMUTABLE;
        }
        _usbPermissionIntent = PendingIntent.getBroadcast(this, 0, new Intent(ACTION_USB_PERMISSION), intentFlags);
    }

    @Override
    protected void onDestroy()
    {
        try {
            releaseMulticastLock();
            releaseWakeLock();
        } catch(final Exception e) {
           Log.e(TAG, "Exception onDestroy()", e);
        }

        super.onDestroy();
    }

    private void releaseMulticastLock()
    {
        if (_wifiMulticastLock != null) {
            _wifiMulticastLock.release();
            Log.d(TAG, "Multicast lock released.");
        }
    }

    private void releaseWakeLock()
    {
        if(_wakeLock != null) {
            _wakeLock.release();
        }
    }

    public void onInit(int status)
    {

    }

    private static UsbSerialDriver _findDriverByDeviceId(int deviceId)
    {
        for (final UsbSerialDriver driver: _drivers) {
            if (driver.getDevice().getDeviceId() == deviceId) {
                return driver;
            }
        }

        return null;
    }

    private static UsbSerialDriver _findDriverByDeviceName(final String deviceName)
    {
        for (final UsbSerialDriver driver: _drivers) {
            if (driver.getDevice().getDeviceName().equals(deviceName)) {
                return driver;
            }
        }

        return null;
    }

    public static void refreshUsbDevices()
    {
        final UsbSerialProber usbDefaultProber = UsbSerialProber.getDefaultProber();
        final UsbSerialProber usbQGCProber = QGCProber.getQGCProber();

        _drivers.clear();
        for (final UsbDevice device : _usbManager.getDeviceList().values()) {
            UsbSerialDriver driver = usbDefaultProber.probeDevice(device);
            if (driver == null) {
                driver = usbQGCProber.probeDevice(device);
            }
            if (driver != null) {
                _drivers.add(driver);
            }
        }
    }

    /**
     * @brief Incrementally updates the list of drivers connected to the device.
     */
    private static void updateCurrentDrivers()
    {
        final UsbSerialProber usbDefaultProber = UsbSerialProber.getDefaultProber();
        List<UsbSerialDriver> currentDrivers = usbDefaultProber.findAllDrivers(_usbManager);
        if (currentDrivers.isEmpty()) {
            currentDrivers = QGCProber.getQGCProber().findAllDrivers(_usbManager);
        }

        if (currentDrivers.isEmpty()) {
            return;
        }

        removeStaleDrivers(currentDrivers);

        addNewDrivers(currentDrivers);
    }

    private static void removeStaleDrivers(final List<UsbSerialDriver> currentDrivers)
    {
        for (int i = _drivers.size() - 1; i >= 0; i--) {
            boolean found = false;
            for (final UsbSerialDriver currentDriver : currentDrivers) {
                if (_drivers.get(i).getDevice().getDeviceId() == currentDriver.getDevice().getDeviceId()) {
                    found = true;
                    break;
                }
            }

            if (!found) {
                qgcLogDebug("Remove stale driver " + _drivers.get(i).getDevice().getDeviceName());
                _drivers.remove(i);
            }
        }
    }

    private static void addNewDrivers(final List<UsbSerialDriver> currentDrivers)
    {
        for (final UsbSerialDriver newDriver : currentDrivers) {
            boolean found = false;
            for (final UsbSerialDriver driver : _drivers) {
                if (newDriver.getDevice().getDeviceId() == driver.getDevice().getDeviceId()) {
                    found = true;
                    break;
                }
            }

            if (!found) {
                addDriver(newDriver);
            }
        }
    }

    private static void addDriver(final UsbSerialDriver newDriver)
    {
        final UsbDevice device = newDriver.getDevice();
        final String deviceName = device.getDeviceName();

        _drivers.add(newDriver);
        qgcLogDebug("Adding new driver " + deviceName);

        if (_usbManager.hasPermission(device)) {
            qgcLogDebug("Already have permission to use device " + deviceName);
        } else {
            qgcLogDebug("Requesting permission to use device " + deviceName);
            _usbManager.requestPermission(device, _usbPermissionIntent);
        }
    }

    /**
     * @brief Returns an array of device info for each unopened device.
     *
     * @return String[] Device info in the format "DeviceName:Company:ProductId:VendorId".
     */
    public static String[] availableDevicesInfo()
    {
        updateCurrentDrivers();

        if (_drivers.size() <= 0) {
            return null;
        }

        final List<String> deviceInfoList = new ArrayList<>();

        for (final UsbSerialDriver driver : _drivers) {
            final UsbSerialPort port = driver.getPorts().get(0);
            final UsbDevice device = driver.getDevice();
            final String deviceInfo = formatDeviceInfo(device, driver);

            deviceInfoList.add(deviceInfo);
        }

        return deviceInfoList.toArray(new String[0]);
    }

    private static String formatDeviceInfo(final UsbDevice device, final UsbSerialDriver driver)
    {
        String deviceInfo = device.getDeviceName() + ":";

        if (driver instanceof FtdiSerialDriver) {
            deviceInfo += "FTDI:";
        } else if (driver instanceof CdcAcmSerialDriver) {
            deviceInfo += "Cdc Acm:";
        } else if (driver instanceof Cp21xxSerialDriver) {
            deviceInfo += "Cp21xx:";
        } else if (driver instanceof ProlificSerialDriver) {
            deviceInfo += "Prolific:";
        } else if (driver instanceof Ch34xSerialDriver) {
            deviceInfo += "CH34x:";
        } else if (driver instanceof ChromeCcdSerialDriver) {
            deviceInfo += "Chrome CCD:";
        } else if (driver instanceof GsmModemSerialDriver) {
            deviceInfo += "GSM Modem:";
        } else {
            deviceInfo += "Unknown:";
        }

        deviceInfo += device.getProductId() + ":";
        deviceInfo += device.getVendorId() + ":";

        return deviceInfo;
    }

    /**
     * Format device information for display.
     *
     * @param driver UsbSerialDriver instance.
     * @return String containing formatted device information.
     */
    private static String formatDeviceInfo(final UsbSerialDriver driver)
    {
        final UsbDevice device = driver.getDevice();
        final List<UsbSerialPort> ports = driver.getPorts();
        StringBuilder sb = new StringBuilder();

        sb.append(String.format("Vendor %04X Product %04X", device.getVendorId(), device.getProductId()));

        for (int i = 0; i < ports.size(); i++) {
            final UsbSerialPort port = ports.get(i);
            sb.append("\nPort ").append(i).append(": ");
            sb.append(String.format("Port number %d", port.getPortNumber()));
        }

        return sb.toString();
    }

    /**
     * @brief Opens the specified device.
     *
     * @param userData Data to associate with the device and pass back through to native calls.
     * @return int Device ID.
     */
    public static int open(final Context parentContext, final String deviceName, final long userData)
    {
        m_context = parentContext;

        final UsbSerialDriver driver = _findDriverByDeviceName(deviceName);
        if (driver == null) {
            qgcLogWarning("Attempt to open unknown device " + deviceName);
            return BAD_DEVICE_ID;
        }

        final List<UsbSerialPort> ports = driver.getPorts();
        if (ports.isEmpty()) {
            qgcLogWarning("No ports available on device " + deviceName);
            return BAD_DEVICE_ID;
        }

        final UsbSerialPort port = ports.get(0);

        final UsbDevice device = driver.getDevice();
        final int deviceId = device.getDeviceId();

        final long startTime = MonotonicClock.millis();

        try {
            openDriver(port, device, deviceId, userData);
        } catch (final IOException ex) {
            handleOpenException(port, deviceId, ex);
            return BAD_DEVICE_ID;
        }

        final long endTime = MonotonicClock.millis();
        Log.d(TAG, "Time taken to open device: " + (endTime - startTime) + " ms");

        return deviceId;
    }

    private static void openDriver(final UsbSerialPort port, final UsbDevice device, final int deviceId, final long userData) throws IOException
    {
        final UsbDeviceConnection connection = _usbManager.openDevice(device);
        if (connection == null) {
            qgcLogWarning("No Usb Device Connection");
            // add UsbManager.requestPermission(driver.getDevice(), ..) handling here
            return;
        }
        port.open(connection);
        port.setParameters(115200, 8, UsbSerialPort.STOPBITS_1, UsbSerialPort.PARITY_NONE);

        _userDataHashByDeviceId.put(deviceId, userData);

        final SerialInputOutputManager ioManager = configureAndStartIoManager(port, userData);
        _serialIoManager.put(deviceId, ioManager);
        m_Executor.submit(ioManager);

        qgcLogDebug("Port open successful");
    }

    private static void handleOpenException(final UsbSerialPort driver, final int deviceId, final IOException ex)
    {
        _userDataHashByDeviceId.remove(deviceId);

        if (_serialIoManager.get(deviceId) != null) {
            _serialIoManager.get(deviceId).stop();
            _serialIoManager.remove(deviceId);
        }

        qgcLogWarning("Port open exception: " + ex.getMessage());
    }

    public static void startIoManager(final int id)
    {
        if (_serialIoManager.get(id) != null) {
            return;
        }

        final UsbSerialDriver driver = _findDriverByDeviceId(id);
        if (driver == null) {
            return;
        }

        final List<UsbSerialPort> ports = driver.getPorts();
        if (ports.isEmpty()) {
            qgcLogWarning("No ports available on device ID " + id);
            return;
        }

        final UsbSerialPort port = ports.get(0);

        final SerialInputOutputManager manager = configureAndStartIoManager(port, _userDataHashByDeviceId.get(id));
        _serialIoManager.put(id, manager);
        m_Executor.submit(manager);
    }

    public static void stopIoManager(final int id)
    {
        if(_serialIoManager.get(id) == null) {
            return;
        }

        _serialIoManager.get(id).stop();
        _serialIoManager.remove(id);
    }

    private static SerialInputOutputManager configureAndStartIoManager(final UsbSerialPort port, final long userData)
    {
        final SerialInputOutputManager ioManager = new SerialInputOutputManager(port, m_Listener, userData);

        // ioManager.setReadBufferSize(8192);
        // ioManager.setWriteBufferSize(8192);

        // ioManager.getReadBufferSize();
        // ioManager.getWriteBufferSize();

        try {
            ioManager.setReadTimeout(1000);
        } catch (final IllegalStateException e) {
            qgcLogWarning("Set Read Timeout exception: " + e.getMessage());
        }

        ioManager.setWriteTimeout(1000);

        // try {
        //     ioManager.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO);
        // } catch (final IllegalStateException e) {
        //     qgcLogWarning("Set Thread Priority exception: " + e.getMessage());
        // }

        try {
            ioManager.start();
        } catch (final IllegalStateException e) {
            qgcLogWarning("IO Manager Start exception: " + e.getMessage());
        }

        // final State ioState = ioManager.getState();
        // STOPPED,
        // RUNNING,
        // STOPPING

        return ioManager;
    }

    /**
     * @brief Sets the parameters on an open port.
     *
     * @param id ID number from the open command.
     * @param baudRate Decimal value of the baud rate. For example, 9600, 57600, 115200, etc.
     * @param dataBits Number of data bits. Valid numbers are 5, 6, 7, 8.
     * @param stopBits Number of stop bits. Valid numbers are 1, 2.
     * @param parity Parity setting: No Parity=0, Odd Parity=1, Even Parity=2.
     * @return true if the operation is successful, false otherwise.
     */
    public static boolean setParameters(final int id, final int baudRate, final int dataBits, final int stopBits, final int parity)
    {
        final UsbSerialDriver driver = _findDriverByDeviceId(id);

        if (driver == null) {
            return false;
        }

        final List<UsbSerialPort> ports = driver.getPorts();
        if (ports.isEmpty()) {
            qgcLogWarning("No ports available on device ID " + id);
            return false;
        }

        final UsbSerialPort port = ports.get(0);

        try {
            port.setParameters(baudRate, dataBits, stopBits, parity);
        } catch (final IOException e) {
            Log.e(TAG, "Error setting parameters", e);
            return false;
        }

        return true;
    }

    /**
     * @brief Closes the device.
     *
     * @param id ID number from the open command.
     * @return true if the operation is successful, false otherwise.
     */
    public static boolean close(int id)
    {
        final UsbSerialDriver driver = _findDriverByDeviceId(id);

        if (driver == null) {
            return false;
        }

        final List<UsbSerialPort> ports = driver.getPorts();
        if (ports.isEmpty()) {
            qgcLogWarning("No ports available on device ID " + id);
            return false;
        }

        final UsbSerialPort port = ports.get(0);

        try {
            closeDriver(port, id);
        } catch (final IOException e) {
            Log.e(TAG, "Error closing device", e);
            return false;
        }

        return true;
    }

    private static void closeDriver(final UsbSerialPort port, final int id) throws IOException
    {
        stopIoManager(id);
        _userDataHashByDeviceId.remove(id);

        port.close();
    }

    /**
     * @brief Writes data to the device.
     *
     * @param id ID number from the open command.
     * @param source Byte array of data to write.
     * @param timeoutMsec Amount of time in milliseconds to wait for the write to occur.
     * @return int Number of bytes written.
     */
    public static int write(final int id, final byte[] source, final int timeoutMSec)
    {
        final UsbSerialDriver driver = _findDriverByDeviceId(id);

        if (driver == null) {
            return 0;
        }

        final List<UsbSerialPort> ports = driver.getPorts();
        if (ports.isEmpty()) {
            qgcLogWarning("No ports available on device ID " + id);
            return 0;
        }

        final UsbSerialPort port = ports.get(0);

        try {
            port.write(source, timeoutMSec);
        } catch (final SerialTimeoutException e) {
            Log.e(TAG, "Write timeout occurred", e);
            return -1;
        } catch (final IOException e) {
            Log.e(TAG, "Error writing data", e);
            return -1;
        }

        return 0;
    }

    /**
     * Writes data to the device asynchronously.
     *
     * @param id ID number from the open command.
     * @param data Byte array of data to write.
     */
    public static void writeAsync(final int id, final byte[] data)
    {
        final SerialInputOutputManager ioManager = _serialIoManager.get(id);

        if (ioManager != null) {
            ioManager.writeAsync(data);
        } else {
            Log.w(TAG, "IO Manager not found for device ID " + id);
        }
    }

    public static byte[] readWithTimeout(final int id, final int timeoutMs) throws IOException
    {
        final UsbSerialDriver driver = _findDriverByDeviceId(id);

        if (driver == null) {
            throw new IOException("Device not found");
        }

        final List<UsbSerialPort> ports = driver.getPorts();
        if (ports.isEmpty()) {
            throw new IOException("No ports available on device ID " + id);
        }

        final UsbSerialPort port = ports.get(0);
        long startTime = MonotonicClock.millis();
        byte[] buffer = new byte[1024];
        int bytesRead = 0;

        while ((MonotonicClock.millis() - startTime) < timeoutMs) {
            bytesRead = port.read(buffer, 100);
            if (bytesRead > 0) {
                break;
            }
        }

        if (bytesRead == 0) {
            throw new SerialTimeoutException("Read operation timed out", bytesRead);
        }

        return buffer;
    }

    public static boolean isDeviceNameValid(final String name)
    {
        for (final UsbSerialDriver driver: _drivers) {
            if (driver.getDevice().getDeviceName().equals(name)) {
                return true;
            }
        }

        return false;
    }

    public static boolean isDeviceNameOpen(final String name)
    {
        for (final UsbSerialDriver driver: _drivers) {
            final List<UsbSerialPort> ports = driver.getPorts();
            if (!ports.isEmpty() && name.equals(driver.getDevice().getDeviceName()) && ports.get(0).isOpen()) {
                return true;
            }
        }

        return false;
    }

    /**
     * @brief Sets the Data Terminal Ready (DTR) flag on the device.
     *
     * @param id ID number from the open command.
     * @param on true to turn on, false to turn off.
     * @return true if the operation is successful, false otherwise.
     */
    public static boolean setDataTerminalReady(final int id, final boolean on)
    {
        final UsbSerialDriver driver = _findDriverByDeviceId(id);

        if (driver == null) {
            return false;
        }

        final List<UsbSerialPort> ports = driver.getPorts();
        if (ports.isEmpty()) {
            qgcLogWarning("No ports available on device ID " + id);
            return false;
        }

        final UsbSerialPort port = ports.get(0);

        EnumSet<UsbSerialPort.ControlLine> supportedControlLines;

        try {
            supportedControlLines = port.getSupportedControlLines();
        } catch (final IOException e) {
            Log.e(TAG, "Error getting supported control lines", e);
            return false;
        }

        if (!supportedControlLines.contains(UsbSerialPort.ControlLine.DTR)) {
            Log.e(TAG, "Setting DTR Not Supported");
            return false;
        }

        try {
            port.setDTR(on);
        } catch (final IOException e) {
            Log.e(TAG, "Error setting DTR", e);
            return false;
        }

        return true;
    }

    /**
     * @brief Sets the Request to Send (RTS) flag.
     *
     * @param id ID number from the open command.
     * @param on true to turn on, false to turn off.
     * @return true if the operation is successful, false otherwise.
     */
    public static boolean setRequestToSend(final int id, final boolean on)
    {
        final UsbSerialDriver driver = _findDriverByDeviceId(id);

        if (driver == null) {
            return false;
        }

        final List<UsbSerialPort> ports = driver.getPorts();
        if (ports.isEmpty()) {
            qgcLogWarning("No ports available on device ID " + id);
            return false;
        }

        final UsbSerialPort port = ports.get(0);

        EnumSet<UsbSerialPort.ControlLine> supportedControlLines;

        try {
            supportedControlLines = port.getSupportedControlLines();
        } catch (final IOException e) {
            Log.e(TAG, "Error getting supported control lines", e);
            return false;
        }

        if (!supportedControlLines.contains(UsbSerialPort.ControlLine.RTS)) {
            Log.e(TAG, "Setting RTS Not Supported");
            return false;
        }

        try {
            port.setRTS(on);
        } catch (final IOException e) {
            Log.e(TAG, "Error setting RTS", e);
            return false;
        }

        return true;
    }

    /**
     * Sets the break condition on the device.
     *
     * @param id ID number from the open command.
     * @param on true to set break, false to clear break.
     * @return true if the operation is successful, false otherwise.
     */
    public static boolean setBreak(int id, boolean on)
    {
        final UsbSerialDriver driver = _findDriverByDeviceId(id);

        if (driver == null) {
            return false;
        }

        final List<UsbSerialPort> ports = driver.getPorts();
        if (ports.isEmpty()) {
            qgcLogWarning("No ports available on device ID " + id);
            return false;
        }

        final UsbSerialPort port = ports.get(0);

        try {
            port.setBreak(on);
        } catch (IOException e) {
            Log.e(TAG, "Error setting break condition", e);
            return false;
        }

        return true;
    }

    /**
     * @brief Purges the hardware buffers based on the input and output flags.
     *
     * @param id ID number from the open command.
     * @param input true to purge the input buffer.
     * @param output true to purge the output buffer.
     * @return true if the operation is successful, false otherwise.
     */
    public static boolean purgeBuffers(final int id, final boolean input, final boolean output)
    {
        final UsbSerialDriver driver = _findDriverByDeviceId(id);

        if (driver == null) {
            return false;
        }

        final List<UsbSerialPort> ports = driver.getPorts();
        if (ports.isEmpty()) {
            qgcLogWarning("No ports available on device ID " + id);
            return false;
        }

        final UsbSerialPort port = ports.get(0);

        try {
            port.purgeHwBuffers(input, output);
        } catch (IOException e) {
            Log.e(TAG, "Error purging buffers", e);
            return false;
        }

        return true;
    }

    /**
     * @brief Gets the native device handle (file descriptor).
     *
     * @param id ID number from the open command.
     * @return int Device handle.
     */
    public static int getDeviceHandle(final int id)
    {
        final UsbSerialDriver driver = _findDriverByDeviceId(id);

        if (driver == null) {
            return -1;
        }

        final UsbDeviceConnection connect = _usbManager.openDevice(driver.getDevice());
        if (connect == null) {
            return -1;
        }

        return connect.getFileDescriptor();
    }

    public static void logUsbDescriptors(int deviceId)
    {
        final UsbSerialDriver driver = _findDriverByDeviceId(deviceId);

        if (driver == null) {
            Log.w(TAG, "No driver found for device ID " + deviceId);
            return;
        }

        final UsbDeviceConnection connection = _usbManager.openDevice(driver.getDevice());
        if (connection == null) {
            Log.w(TAG, "No connection found for device ID " + deviceId);
            return;
        }

        final ArrayList<byte[]> descriptors = UsbUtils.getDescriptors(connection);
        for (byte[] descriptor : descriptors) {
            Log.d(TAG, "Descriptor: " + HexDump.toHexString(descriptor));
        }
    }

    public static String getSDCardPath()
    {
        final StorageManager storageManager = (StorageManager) _instance.getSystemService(Activity.STORAGE_SERVICE);
        final List<StorageVolume> volumes = storageManager.getStorageVolumes();
        for (final StorageVolume vol : volumes) {
            final String path = getStorageVolumePath(vol);
            if (path != null) {
                return path;
            }
        }

        return "";
    }

    private static String getStorageVolumePath(final StorageVolume vol)
    {
        try {
            final Method mMethodGetPath = vol.getClass().getMethod("getPath");
            final String path = (String) mMethodGetPath.invoke(vol);
            if (vol.isRemovable()) {
                Log.i(TAG, "removable sd card mounted " + path);
                return path;
            } else {
                Log.i(TAG, "storage mounted " + path);
            }
        } catch (final Exception e) {
            Log.e(TAG, "Error getting storage volume path", e);
        }

        return null;
    }
}
