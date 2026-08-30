package com.ling.ap.Utils;

import com.qcloud.cos.region.Region;

//常量的类
public class Const {

    //百度数据
    public static final String API_KEY = "";
    public static final String SECRET_KEY = "";

    public static final String SPEECH_API_KEY = "";
    public static final String SPEECH_SECRET_KEY = "";


    //jwt的加密数据
    public  static  final String JWT_BYTE = "eldercare100-deployment-jwt-signing-key-ec099";

    //阿里短信数据
    public static final String ACCESS_KEY_ID="";
    public static final String ACCESS_KEY_SECRE="";

    //阿里短信模板名称
    public static final String SOS_TEMPLATE_CODE ="";//求救模板
    public static final String VERIFICATION_TEMPLATE_CODE="";//验证码的模板
    //阿里短信签名名称
    public static final String SIGN_NAME="";

    //腾讯短信数据
    public static final String SecretId="";
    public static final String SecretKey="";
    public static final String APP_KEY_ID="";

    //腾讯短信模板名称
    public static final String T_SOS_TEMPLATE_CODE ="";//求救模板
    public static final String T_VERIFICATION_TEMPLATE_CODE_R="";//登录验证码的模板
    public static final String T_VERIFICATION_TEMPLATE_CODE_L="";//注册验证码的模板

    //腾讯短信签名名称
    public static final String T_SIGN_NAME="";

    //日历
    public static final String APP_ID="";
    public static final String APP_SECRET="";

    //腾讯COS桶
    public static final String COS_SECRET_ID = "";
    public static final String COS_SECRET_KEY = "";
    public static final Region COS_REGION = new Region("");
    public static final String COS_BUCKET_NAME = "";// 指定文件将要存放的存储桶
    public static final String COS_PATH="";
//    public static final String URI ="https://e-1314112329.cos.ap-guangzhou.myqcloud.com/HeadSculpture";

    //系统消息发生Id
    public static final String COUNTER_FRAUD="";//反诈消息
}
