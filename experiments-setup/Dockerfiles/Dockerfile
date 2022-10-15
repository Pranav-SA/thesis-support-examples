FROM python:3.8.1-alpine

LABEL maintainer="Pranav Shankar < pranavshankar.work@gmail.com >"

RUN apk add --no-cache --virtual build-deps gcc g++ git libffi-dev linux-headers python3-dev musl-dev && \
    pip install --no-cache-dir  -q -U pip && \
    pip install --no-cache-dir chaostoolkit && \
    pip install --no-cache-dir chaostoolkit-kubernetes && \
    pip install --no-cache-dir chaostoolkit-istio && \
    pip install --no-cache-dir chaostoolkit-aws && \
    pip install --no-cache-dir chaostoolkit-google-cloud-platform && \
    pip install --no-cache-dir chaostoolkit-azure && \
    pip install --no-cache-dir chaostoolkit-slack && \
    pip install --no-cache-dir slackclient==1.3.2 && \
    apk del build-deps

ENTRYPOINT ["/usr/local/bin/chaos"]
CMD ["--help"]