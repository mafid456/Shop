# Dockerfile
FROM nginx:alpine
COPY . /usr/share/nginx/html
EXPOSE 8083
CMD ["nginx", "-g", "daemon off;"]
