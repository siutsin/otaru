{{/*
Media Drive Volume
*/}}
{{- define "jellyfin.volume" -}}
- name: jellyfin-media-0000
  persistentVolumeClaim:
    claimName: jellyfin-media-0000-pvc
- name: jellyfin-media-0001
  persistentVolumeClaim:
    claimName: jellyfin-media-0001-pvc
- name: jellyfin-media-0002
  persistentVolumeClaim:
    claimName: jellyfin-media-0002-pvc
- name: jellyfin-media-0003
  persistentVolumeClaim:
    claimName: jellyfin-media-0003-pvc
- name: jellyfin-media-1000
  persistentVolumeClaim:
    claimName: jellyfin-media-1000-pvc
- name: jellyfin-media-1001
  persistentVolumeClaim:
    claimName: jellyfin-media-1001-pvc
- name: jellyfin-media-1002
  persistentVolumeClaim:
    claimName: jellyfin-media-1002-pvc
- name: jellyfin-media-1003
  persistentVolumeClaim:
    claimName: jellyfin-media-1003-pvc
- name: jellyfin-media-1004
  persistentVolumeClaim:
    claimName: jellyfin-media-1004-pvc
- name: jellyfin-media-1005
  persistentVolumeClaim:
    claimName: jellyfin-media-1005-pvc
- name: jellyfin-media-2000
  persistentVolumeClaim:
    claimName: jellyfin-media-2000-pvc
{{- end }}

{{/*
Media Drive Volume Mount
*/}}
{{- define "jellyfin.volumeMount" -}}
- name: jellyfin-media-0000
  mountPath: /media/0000
- name: jellyfin-media-0001
  mountPath: /media/0001
- name: jellyfin-media-0002
  mountPath: /media/0002
- name: jellyfin-media-0003
  mountPath: /media/0003
- name: jellyfin-media-1000
  mountPath: /media/1000
- name: jellyfin-media-1001
  mountPath: /media/1001
- name: jellyfin-media-1002
  mountPath: /media/1002
- name: jellyfin-media-1003
  mountPath: /media/1003
- name: jellyfin-media-1004
  mountPath: /media/1004
- name: jellyfin-media-1005
  mountPath: /media/1005
- name: jellyfin-media-2000
  mountPath: /media/2000
{{- end }}

{{/*
Common Probe
*/}}
{{- define "jellyfin.probe" -}}
httpGet:
  path: /
  port: http
{{- end }}

{{/*
Telemetry Probe
*/}}
{{- define "jellyfin.telemetryProbe" -}}
httpGet:
  path: /healthz
  port: telemetry
{{- end }}
