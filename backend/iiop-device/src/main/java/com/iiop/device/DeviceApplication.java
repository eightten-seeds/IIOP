package com.iiop.device;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;

@EnableDiscoveryClient @MapperScan("com.iiop.device.mapper") @SpringBootApplication
public class DeviceApplication {
    public static void main(String[] args){SpringApplication.run(DeviceApplication.class,args);}
}
