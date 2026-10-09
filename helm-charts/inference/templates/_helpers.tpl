{{/*
Server env. The sidecar uses the same block, so both compute the same cache key.
*/}}
{{- define "inference.serverEnv" -}}
- name: LLAMA_ARG_PORT
  value: {{ .Values.service.targetPort | quote }}
- name: LLAMA_ARG_SPEC_DRAFT_MODEL
  value: {{ .Values.drafter.path | quote }}
- name: SLOT_PATH
  value: {{ .Values.slotCache.path | quote }}
{{- range $name, $value := .Values.deployment.env }}
- name: {{ $name }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}
