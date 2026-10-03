FROM node:22-slim

WORKDIR /app

# Install dependencies
COPY package.json package-lock.json ./
RUN npm ci

# Copy in playground
COPY . ./

# Serve it up!
CMD ["npm", "run", "dev", "--", "-p", "3000"]
EXPOSE 3000