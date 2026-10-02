{{- define "ecommerce.labels" -}}
app.kubernetes.io/name: ecommerce
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "ecommerce.secretName" -}}
{{- if .Values.database.existingSecret -}}{{ .Values.database.existingSecret }}{{- else -}}ecommerce-secrets{{- end -}}
{{- end -}}

{{- define "ecommerce.backendImage" -}}
{{ .Values.image.registry }}/{{ .Values.image.backendRepository }}:{{ .Values.image.tag }}
{{- end -}}

{{- define "ecommerce.frontendImage" -}}
{{ .Values.image.registry }}/{{ .Values.image.frontendRepository }}:{{ .Values.image.tag }}
{{- end -}}
