package com.jstyle.blesdkx3.Util;



/**
 * Created by Administrator on 2018/7/25.
 */

public class Temperature3NtcData {
    float tempValue;
    float tempValue2;
    float tempValue3;
    float changtemp;//算法出的新数据
    int tempStatus;//状态  0: wear off; 1: wearon; 2: slp in;3:slp out 4:normal high temperature 5: Abnormal high temperature 6: warming  7：slp w lowT


    public Temperature3NtcData() {
        super();
    }
    public Temperature3NtcData(float a,float b,float c) {
        this.tempValue = a;
        this.tempValue2 = b;
        this.tempValue3 = c;
    }
    public float getTempValue() {
        return tempValue;
    }

    public void setTempValue(float tempValue) {
        this.tempValue = tempValue;
    }

    public float getTempValue2() {
        return tempValue2;
    }

    public void setTempValue2(float tempValue2) {
        this.tempValue2 = tempValue2;
    }

    public float getTempValue3() {
        return tempValue3;
    }

    public void setTempValue3(float tempValue3) {
        this.tempValue3 = tempValue3;
    }

    public float getChangtemp() {
        return changtemp;
    }

    public void setChangtemp(float changtemp) {
        this.changtemp = changtemp;
    }

    public int getTempStatus() {
        return tempStatus;
    }

    public void setTempStatus(int tempStatus) {
        this.tempStatus = tempStatus;
    }

    @Override
    public String toString() {
        return "Temperature3NtcData{" +
                "tempValue=" + tempValue +
                ", tempValue2=" + tempValue2 +
                ", tempValue3=" + tempValue3 +
                ", changtemp=" + changtemp +
                '}';
    }
}
