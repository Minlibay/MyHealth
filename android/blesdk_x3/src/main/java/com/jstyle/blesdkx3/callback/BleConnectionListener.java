package com.jstyle.blesdkx3.callback;

public interface BleConnectionListener {
    void BleStatus(int status,int newState);//蓝牙4.0连接状态 Bluetooth 4.0 connection status
    void ConnectionSucceeded();//连接设备成功 Successfully connected the device
    void Connecting();//设备连接中 Device is connected
    void ConnectionFailed();//设备连接失败 Device connection failed
    void OnReconnect();//重新连接中 Reconnecting
    void BluetoothSwitchIsTurnedOff();//蓝牙开关被关闭 Bluetooth switch is turned off
}
