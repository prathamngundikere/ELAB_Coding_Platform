FROM node:18-slim

WORKDIR /app

COPY package*.json ./

FROM node:18-slim

WORKDIR /app

# Copy from elab directory instead of root
COPY elab/package*.json ./

RUN npm install

# Copy the entire elab directory content to /app
COPY elab/ .

EXPOSE 4000

CMD ["node", "app.js"]
