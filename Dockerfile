FROM node:22-bullseye

# Install system dependencies (THIS is why Docker solves your problem)
RUN apt-get update && apt-get install -y \
    nasm \
    gcc \
    make \
    build-essential

# Set working directory
WORKDIR /app

# Copy package files first (better caching)
COPY package*.json ./

# Install Node dependencies
RUN npm install

# Copy rest of the code
COPY . .

# Build your C compiler
RUN make

# Expose port (adjust if your app uses a different one)
EXPOSE 8080

# Start your app
CMD ["node", "app.js"]
