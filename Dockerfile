FROM maprtech/data-science-refinery:v1.4.1_6.1.0_6.3.0_centos7

ENTRYPOINT []
CMD exec /bin/bash -c "trap : TERM INT; sleep infinity & wait"
