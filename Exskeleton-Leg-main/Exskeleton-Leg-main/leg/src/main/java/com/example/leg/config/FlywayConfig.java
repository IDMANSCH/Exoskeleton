package com.example.leg.config;

import javax.sql.DataSource;
import org.flywaydb.core.Flyway;
import org.springframework.beans.factory.config.BeanFactoryPostProcessor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class FlywayConfig {
    @Bean(initMethod = "migrate")
    Flyway flyway(DataSource dataSource, @Value("${spring.flyway.locations:classpath:db/migration}") String locations) {
        return Flyway.configure()
                .dataSource(dataSource)
                .locations(locations)
                .baselineOnMigrate(true)
                .load();
    }

    @Bean
    static BeanFactoryPostProcessor entityManagerFactoryDependsOnFlyway() {
        return beanFactory -> {
            for (String beanName : beanFactory.getBeanNamesForType(jakarta.persistence.EntityManagerFactory.class, true, false)) {
                var definition = beanFactory.getBeanDefinition(beanName);
                definition.setDependsOn(append(definition.getDependsOn(), "flyway"));
            }
            if (beanFactory.containsBeanDefinition("entityManagerFactory")) {
                var definition = beanFactory.getBeanDefinition("entityManagerFactory");
                definition.setDependsOn(append(definition.getDependsOn(), "flyway"));
            }
        };
    }

    private static String[] append(String[] values, String value) {
        if (values == null || values.length == 0) {
            return new String[] {value};
        }
        var result = java.util.Arrays.copyOf(values, values.length + 1);
        result[values.length] = value;
        return result;
    }
}
