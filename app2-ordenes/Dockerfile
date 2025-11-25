FROM node:18

# Directorio de trabajo
WORKDIR /app

# Copiamos package.json
COPY package.json .

# Instalamos dependencias
RUN npm install

# Copiamos el código fuente
COPY . .

# Exponemos el puerto interno (8002)
EXPOSE 8002

# Comando de inicio
CMD ["node", "src/index.js"]
