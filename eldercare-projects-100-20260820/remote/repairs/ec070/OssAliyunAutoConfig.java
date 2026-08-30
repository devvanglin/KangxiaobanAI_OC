package com.zzyl.config;

import com.aliyun.oss.OSS;
import com.aliyun.oss.OSSClientBuilder;
import com.zzyl.properties.AliOssConfigProperties;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Slf4j
@Configuration
public class OssAliyunAutoConfig {

    @Autowired
    AliOssConfigProperties aliOssConfigProperties;

    @Bean
    public OSS ossClient(){
        log.info("-----------------开始创建OSSClient--------------------");
        OSS ossClient = new OSSClientBuilder().build(aliOssConfigProperties.getEndpoint(),
                aliOssConfigProperties.getAccessKeyId(), aliOssConfigProperties.getAccessKeySecret());
        // Deployment acceptance must not call a third-party OSS account during
        // Spring context creation. Upload/delete operations still use the
        // configured client and remain unverified without valid OSS credentials.

        log.info("-----------------结束创建OSSClient--------------------");
        return ossClient;
    }


}
