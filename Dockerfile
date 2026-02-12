FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html style.css /usr/share/nginx/html/
COPY posts /usr/share/nginx/html/posts
COPY images /usr/share/nginx/html/images
