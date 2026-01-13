# Base image - official WSO2 Micro Integrator
FROM wso2/wso2mi:4.4.0

# Set working directory to where WSO2 deploys CAR files
WORKDIR /home/wso2carbon/wso2mi-4.4.0/repository/deployment/server/carbonapps/

# Copy Project Integration (CAR file)
COPY ./AppointmentServices_1.0.0.car ./

# Expose API and management ports
EXPOSE 8290 8253

# Switch back to wso2carbon user (default)
USER wso2carbon

# Start WSO2 Micro Integrator automatically
CMD ["/home/wso2carbon/wso2mi-4.4.0/bin/micro-integrator.sh"]
