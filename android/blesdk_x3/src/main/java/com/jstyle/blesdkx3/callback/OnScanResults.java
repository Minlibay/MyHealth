package com.jstyle.blesdkx3.callback;


import com.jstyle.blesdkx3.model.Device;

public interface OnScanResults {
  void Success(Device date);
  void Fail(int code);
}
