package com.jstyle.blesdkx3.Util;

import android.util.Log;



import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

/**
 * 用于3ntc 设备计算温度
 */
public class TemperatureUtils {
    private static final float cfAbnormalHighTemperatureThreshold = 41.5f;
    private static final float cfColdTemperatureThreshold = 10.0f;
    private static final float cfLowTemperatureThreshold = 30.0f;
    private static final float cfHighTemperatureThreshold = 37.3f;

    public static Temperature3NtcData vCalculatingBodyTemperature(Temperature3NtcData data) {
       // List<Temperature3NtcData> miandata = new ArrayList<>();
        /*if (!data.isEmpty()) {*/
           // Log.e("asdadada", data.get(data.size()-1).toString()+"\nvv");
         /*   for (int jj = 0; jj < data.size(); jj++) {*/
               // int index = jj;
                float[] arr = new float[]{data.getTempValue(), data.getTempValue2(), data.getTempValue3()};
                float maxValue = max(arr, 3);
                float minValue = min(arr, 3);
                float diffTemperature = maxValue - minValue;
                Temperature3NtcData temperature3NtcData = data/*.get(index)*/;
               // miandata.add(temperature3NtcData);
                if (maxValue > cfAbnormalHighTemperatureThreshold - 0.25f) {
                    temperature3NtcData.setTempStatus(5);
                    temperature3NtcData.setChangtemp(OneFloat(maxValue + 0.2f));
                } else if (maxValue > cfHighTemperatureThreshold - 0.25f) {
                    if (diffTemperature < 0.25f) {
                        temperature3NtcData.setTempStatus(4);
                        temperature3NtcData.setChangtemp(OneFloat(maxValue + 0.2f));
                    } else if (diffTemperature < 0.85f) {
                        temperature3NtcData.setChangtemp(OneFloat(maxValue + (diffTemperature + 0.2f) / 2f));
                        if (temperature3NtcData.getChangtemp()> 41.4f) {
                            temperature3NtcData.setTempStatus(5);
                        } else {
                            temperature3NtcData.setTempStatus(4);
                        }
                    } else if (diffTemperature < 1.85f) {
                        temperature3NtcData.setChangtemp(OneFloat(maxValue + 0.5f + (diffTemperature - 0.8f) / 4f));
                        if (temperature3NtcData.getChangtemp()> 41.4f) {
                            temperature3NtcData.setTempStatus(5);
                        } else {
                            temperature3NtcData.setTempStatus(4);
                        }
                    } else {
                        temperature3NtcData.setTempStatus(6);
                        temperature3NtcData.setChangtemp(OneFloat(maxValue + 0.5f));
                    }
                } else if (maxValue > 35.95f) {
                    if (diffTemperature < 0.45f) {
                        temperature3NtcData.setTempStatus(2);
                        temperature3NtcData.setChangtemp(OneFloat(maxValue + 0.2f));
                    } else if (diffTemperature < 0.85f) {
                        temperature3NtcData.setChangtemp(OneFloat(maxValue +  (diffTemperature) / 2f));
                        if (temperature3NtcData.getChangtemp() > 37.25f) {
                            temperature3NtcData.setTempStatus(4);
                        } else {
                            temperature3NtcData.setTempStatus(3);
                        }
                    } else if (diffTemperature < 2.05f) {
                       /* LogUtils.d(maxValue);
                        LogUtils.d((diffTemperature) );
                        LogUtils.d(maxValue + 0.3f + (diffTemperature - 0.8f) / 4f);*/
                        temperature3NtcData.setChangtemp(OneFloat(maxValue + 0.3f + (diffTemperature - 0.8f) / 4f));
                        if (temperature3NtcData.getChangtemp() > 37.25f) {
                            temperature3NtcData.setTempStatus(4);
                        } else {
                            temperature3NtcData.setTempStatus(3);
                        }
                    } else {
                        temperature3NtcData.setChangtemp(OneFloat(maxValue + 0.5f));
                        temperature3NtcData.setTempStatus(1);
                    }
                } else if (maxValue > 34.95f) {
                    if (diffTemperature < 0.45f) {
                        temperature3NtcData.setTempStatus(2);
                        temperature3NtcData.setChangtemp(OneFloat(maxValue + 1f));
                    } else if (diffTemperature < 0.85f) {
                        temperature3NtcData.setChangtemp(OneFloat(maxValue + 0.8f + (diffTemperature) / 2f));
                        if (temperature3NtcData.getChangtemp() > 37.25f) {
                            temperature3NtcData.setTempStatus(4);
                        } else {
                            temperature3NtcData.setTempStatus(3);
                        }
                    } else if (diffTemperature < 2.05) {
                        temperature3NtcData.setChangtemp(OneFloat(maxValue + 0.8f + (diffTemperature - 0.8f) / 3f));
                        if (temperature3NtcData.getChangtemp() > 37.25f) {
                            temperature3NtcData.setTempStatus(4);
                        } else {
                            temperature3NtcData.setTempStatus(3);
                        }
                    } else {
                        temperature3NtcData.setChangtemp(OneFloat(maxValue + 1.2f));
                        temperature3NtcData.setTempStatus(1);
                    }
                } else if (maxValue > 33.95f) {
                    if (diffTemperature < 0.45f) {
                        temperature3NtcData.setChangtemp(OneFloat(maxValue + 1.0f + 0.9f));
                        temperature3NtcData.setTempStatus(2);
                    } else if (diffTemperature < 0.85f) {
                        temperature3NtcData.setChangtemp(OneFloat(maxValue + 0.8f + (diffTemperature + 0.2f) / 2f + 0.9f));
                        if (temperature3NtcData.getChangtemp() > 37.25f) {
                            temperature3NtcData.setTempStatus(4);
                        } else {
                            temperature3NtcData.setTempStatus(3);
                        }
                    } else if (diffTemperature < 2.05f) {
                        temperature3NtcData.setChangtemp(OneFloat(maxValue + 1.1f + (diffTemperature - 0.8f) / 4f + 0.9f));
                        if (temperature3NtcData.getChangtemp() > 37.25f) {
                            temperature3NtcData.setTempStatus(4);
                        } else {
                            temperature3NtcData.setTempStatus(3);
                        }
                    } else {
                        temperature3NtcData.setChangtemp(OneFloat( maxValue + 1.3f + 0.9f));
                        temperature3NtcData.setTempStatus(1);
                    }
                } else if (maxValue > cfLowTemperatureThreshold - 0.05f) {
                    if (diffTemperature < 0.45f) {
                        temperature3NtcData.setTempStatus(2);
                        temperature3NtcData.setChangtemp(OneFloat(maxValue + 1.0f + 0.9f));
                    } else if (diffTemperature < 0.85f) {
                        temperature3NtcData.setChangtemp(OneFloat(maxValue + 0.8f + (diffTemperature + 0.2f) / 2f + 0.9f));
                        if (temperature3NtcData.getChangtemp() > 37.25f) {
                            temperature3NtcData.setTempStatus(4);
                        } else {
                            temperature3NtcData.setTempStatus(3);
                        }
                    } else if (diffTemperature < 2.05f) {
                        temperature3NtcData.setChangtemp(OneFloat(maxValue + 1.3f + (diffTemperature - 0.8f) / 4 + 0.9f));
                        if (temperature3NtcData.getChangtemp() > 37.25f) {
                            temperature3NtcData.setTempStatus(4);
                        } else {
                            temperature3NtcData.setTempStatus(3);
                        }
                    } else {
                        temperature3NtcData.setChangtemp(OneFloat(maxValue + 1.3f + 0.9f));
                        temperature3NtcData.setTempStatus(1);
                    }
                } else {
                    temperature3NtcData.setChangtemp(OneFloat(maxValue));
                }
           /* }*/
          //  miandata.get(miandata.size()-1).setSelect(true);//设置选中最后一个数据
//Log.e("asdadada", miandata.get(miandata.size()-1).toString());

         /*   float base=miandata.get(miandata.size()-1).getChangtemp()-36.5f;
            float lastbase=miandata.get(miandata.size()-1).getChangtemp();
            for (int v=0;v<miandata.size();v++){
              //  miandata.get(v).setBase(OneFloat(base));
                float gg=miandata.get(v).getChangtemp();
                miandata.get(v).setChangtemp(OneFloat(gg-lastbase));
            }*/



        /*}*/

        return temperature3NtcData;

    }

    public  static float FindMax(List<Temperature3NtcData> data){
        for (int i=0;i<data.size();i++){
            Log.e("adadada",data.get(i).toString());
        }
        float max=-999f;
        max=data.get(0).getChangtemp();
        for (Temperature3NtcData tt:data){
            if (tt.getChangtemp() > max) {
                max =tt.getChangtemp();
            }
        }
        return max;
    };









    //float 保留小数点后一位，直舍
    protected static float  OneFloat(float VALUE){
        // 使用 BigDecimal 截断小数
        BigDecimal bigDecimal = new BigDecimal(VALUE);
        BigDecimal truncated = bigDecimal.setScale(1, RoundingMode.DOWN);
        return truncated.floatValue();

    }
    // 函数用于求数组的最大值
    protected static float max(float[] arr, int n) {
        float max_val = arr[0];
        for (int i = 1; i < n; i++) {
            if (arr[i] > max_val) {
                max_val = arr[i];
            }
        }
        return max_val;
    }


    // 函数用于求数组的最小值
    protected static float min(float[] arr, int n) {
        float min_val = arr[0];
        for (int i = 1; i < n; i++) {
            if (arr[i] < min_val) {
                min_val = arr[i];
            }
        }
        return min_val;
    }

}
