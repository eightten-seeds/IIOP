package com.iiop.inspection;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.cloud.openfeign.EnableFeignClients;

@EnableDiscoveryClient @EnableFeignClients @MapperScan("com.iiop.inspection.mapper") @SpringBootApplication
public class InspectionApplication {public static void main(String[] args){SpringApplication.run(InspectionApplication.class,args);}}
