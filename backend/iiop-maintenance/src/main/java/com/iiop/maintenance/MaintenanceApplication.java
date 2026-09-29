package com.iiop.maintenance;
import org.mybatis.spring.annotation.MapperScan;import org.springframework.boot.SpringApplication;import org.springframework.boot.autoconfigure.SpringBootApplication;import org.springframework.cloud.client.discovery.EnableDiscoveryClient;import org.springframework.cloud.openfeign.EnableFeignClients;
@EnableDiscoveryClient @EnableFeignClients @MapperScan("com.iiop.maintenance.mapper") @SpringBootApplication
public class MaintenanceApplication {public static void main(String[] a){SpringApplication.run(MaintenanceApplication.class,a);}}
