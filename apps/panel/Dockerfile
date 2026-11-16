# Production-ready Docker image for React application
FROM node:20-alpine

# Install serve globally for serving static files
RUN npm install -g serve

# Create app directory
WORKDIR /app

# Copy the pre-built application (will be copied from workflow)
COPY build/ .

# Expose port 8080
EXPOSE 8080

# Start serve with SPA support
CMD ["serve", "-s", ".", "-l", "8080"]