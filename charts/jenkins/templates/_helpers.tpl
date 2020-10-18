{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "jenkins.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Allow the release namespace to be overridden for multi-namespace deployments in combined charts.
*/}}
{{- define "jenkins.namespace" -}}
  {{- if .Values.namespaceOverride -}}
    {{- .Values.namespaceOverride -}}
  {{- else -}}
    {{- .Release.Namespace -}}
  {{- end -}}
{{- end -}}

{{- define "jenkins.agent.namespace" -}}
  {{- if .Values.agent.namespace -}}
    {{- tpl .Values.agent.namespace . -}}
  {{- else -}}
    {{- if .Values.namespaceOverride -}}
      {{- .Values.namespaceOverride -}}
    {{- else -}}
      {{- .Release.Namespace -}}
    {{- end -}}
  {{- end -}}
{{- end -}}


{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "jenkins.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Returns the Jenkins URL
*/}}
{{- define "jenkins.url" -}}
{{- if .Values.controller.jenkinsUrl }}
  {{- .Values.controller.jenkinsUrl }}
{{- else }}
  {{- if .Values.controller.ingress.hostName }}
    {{- if .Values.controller.ingress.tls }}
      {{- default "https" .Values.controller.jenkinsUrlProtocol }}://{{ .Values.controller.ingress.hostName }}{{ default "" .Values.controller.jenkinsUriPrefix }}
    {{- else }}
      {{- default "http" .Values.controller.jenkinsUrlProtocol }}://{{ .Values.controller.ingress.hostName }}{{ default "" .Values.controller.jenkinsUriPrefix }}
    {{- end }}
  {{- else }}
      {{- default "http" .Values.controller.jenkinsUrlProtocol }}://{{ template "jenkins.fullname" . }}:{{.Values.controller.servicePort}}{{ default "" .Values.controller.jenkinsUriPrefix }}
  {{- end}}
{{- end}}
{{- end -}}

{{/*
Returns configuration as code default config
*/}}
{{- define "jenkins.casc.defaults" -}}
jenkins:
  {{- $configScripts := toYaml .Values.controller.JCasC.configScripts }}
  {{- if and (.Values.controller.JCasC.authorizationStrategy) (not (contains "authorizationStrategy:" $configScripts)) }}
  authorizationStrategy:
    {{- tpl .Values.controller.JCasC.authorizationStrategy . | nindent 4 }}
  {{- end }}
  {{- if and (.Values.controller.JCasC.securityRealm) (not (contains "securityRealm:" $configScripts)) }}
  securityRealm:
    {{- tpl .Values.controller.JCasC.securityRealm . | nindent 4 }}
  {{- end }}
  disableRememberMe: {{ .Values.controller.disableRememberMe }}
  remotingSecurity:
    enabled: true
  mode: {{ .Values.controller.executorMode }}
  numExecutors: {{ .Values.controller.numExecutors }}
  projectNamingStrategy: "standard"
  markupFormatter:
    {{- if .Values.controller.enableRawHtmlMarkupFormatter }}
    rawHtml:
      disableSyntaxHighlighting: true
    {{- else }}
    {{- toYaml .Values.controller.markupFormatter | nindent 4 }}
    {{- end }}
  clouds:
  - kubernetes:
      containerCapStr: "{{ .Values.agent.containerCap }}"
      defaultsProviderTemplate: "{{ .Values.agent.defaultsProviderTemplate }}"
      connectTimeout: "{{ .Values.controller.agentConnectTimeout }}"
      readTimeout: "{{ .Values.controller.agentReadTimeout }}"
      {{- if .Values.controller.agentJenkinsUrl }}
      jenkinsUrl: "{{ tpl .Values.controller.agentJenkinsUrl . }}"
      {{- else if .Values.agent.namespace }}
      jenkinsUrl: "http://{{ template "jenkins.fullname" . }}.{{ template "jenkins.namespace" . }}:{{.Values.controller.servicePort}}{{ default "" .Values.controller.jenkinsUriPrefix }}"
      {{- else }}
      jenkinsUrl: "http://{{ template "jenkins.fullname" . }}:{{.Values.controller.servicePort}}{{ default "" .Values.controller.jenkinsUriPrefix }}"
      {{- end }}

      {{- if .Values.controller.agentJenkinsTunnel }}
      jenkinsTunnel: "{{ tpl .Values.controller.agentJenkinsTunnel . }}"
      {{- else if .Values.agent.namespace }}
      jenkinsTunnel: "{{ template "jenkins.fullname" . }}-agent.{{ template "jenkins.namespace" . }}:{{ .Values.controller.agentListenerPort }}"
      {{- else }}
      jenkinsTunnel: "{{ template "jenkins.fullname" . }}-agent:{{ .Values.controller.agentListenerPort }}"
      {{- end }}
      maxRequestsPerHostStr: "32"
      name: "kubernetes"
      namespace: "{{ template "jenkins.agent.namespace" . }}"
      serverUrl: "https://kubernetes.default"
      {{- if .Values.agent.enabled }}
      podLabels:
      - key: "jenkins/{{ .Release.Name }}-{{ .Values.agent.componentName }}"
        value: "true"
      templates:
      {{- include "jenkins.casc.podTemplate" . | nindent 8 }}
    {{- if .Values.additionalAgents }}
      {{- /* save .Values.agent */}}
      {{- $agent := .Values.agent }}
      {{- range $name, $additionalAgent := .Values.additionalAgents }}
        {{- /* merge original .Values.agent into additional agent to ensure it at least has the default values */}}
        {{- $additionalAgent := merge $additionalAgent $agent }}
        {{- /* set .Values.agent to $additionalAgent */}}
        {{- $_ := set $.Values "agent" $additionalAgent }}
        {{- include "jenkins.casc.podTemplate" $ | nindent 8 }}
      {{- end }}
      {{- /* restore .Values.agent */}}
      {{- $_ := set .Values "agent" $agent }}
    {{- end }}
      {{- if .Values.agent.podTemplates }}
        {{- range $key, $val := .Values.agent.podTemplates }}
          {{- tpl $val $ | nindent 8 }}
        {{- end }}
      {{- end }}
      {{- end }}
  {{- if .Values.controller.csrf.defaultCrumbIssuer.enabled }}
  crumbIssuer:
    standard:
      excludeClientIPFromCrumb: {{ if .Values.controller.csrf.defaultCrumbIssuer.proxyCompatability }}true{{ else }}false{{- end }}
  {{- end }}
security:
  apiToken:
    creationOfLegacyTokenEnabled: false
    tokenGenerationOnCreationEnabled: false
    usageStatisticsEnabled: true
unclassified:
  location:
    adminAddress: {{ default "" .Values.controller.jenkinsAdminEmail }}
    url: {{ template "jenkins.url" . }}
{{- end -}}

{{/*
Returns kubernetes pod template configuration as code
*/}}
{{- define "jenkins.casc.podTemplate" -}}
- name: "{{ .Values.agent.podName }}"
  containers:
  - name: "{{ .Values.agent.sideContainerName }}"
    alwaysPullImage: {{ .Values.agent.alwaysPullImage }}
    args: "{{ .Values.agent.args | replace "$" "^$" }}"
    {{- if .Values.agent.command }}
    command: {{ .Values.agent.command }}
    {{- end }}
    envVars:
      - envVar:
          key: "JENKINS_URL"
          {{- if .Values.controller.agentJenkinsUrl }}
          value: {{ tpl .Values.controller.agentJenkinsUrl . }}
          {{- else }}
          value: "http://{{ template "jenkins.fullname" . }}.{{ template "jenkins.namespace" . }}.svc.{{.Values.clusterZone}}:{{.Values.controller.servicePort}}{{ default "" .Values.controller.jenkinsUriPrefix }}"
          {{- end }}
    {{- if .Values.agent.imageTag }}
    image: "{{ .Values.agent.image }}:{{ .Values.agent.imageTag }}"
    {{- else }}
    image: "{{ .Values.agent.image }}:{{ .Values.agent.tag }}"
    {{- end }}
    privileged: "{{- if .Values.agent.privileged }}true{{- else }}false{{- end }}"
    resourceLimitCpu: {{.Values.agent.resources.limits.cpu}}
    resourceLimitMemory: {{.Values.agent.resources.limits.memory}}
    resourceRequestCpu: {{.Values.agent.resources.requests.cpu}}
    resourceRequestMemory: {{.Values.agent.resources.requests.memory}}
    runAsUser: {{ .Values.agent.runAsUser }}
    runAsGroup: {{ .Values.agent.runAsGroup }}
    ttyEnabled: {{ .Values.agent.TTYEnabled }}
    workingDir: {{ .Values.agent.workingDir }}
{{- if .Values.agent.envVars }}
  envVars:
  {{- range $index, $var := .Values.agent.envVars }}
    - envVar:
        key: {{ $var.name }}
        value: {{ tpl $var.value $ }}
  {{- end }}
{{- end }}
  idleMinutes: {{ .Values.agent.idleMinutes }}
  instanceCap: 2147483647
  {{- if .Values.agent.imagePullSecretName }}
  imagePullSecrets:
  - name: {{ .Values.agent.imagePullSecretName }}
  {{- end }}
  label: "{{ .Release.Name }}-{{ .Values.agent.componentName }} {{ .Values.agent.customJenkinsLabels  | join " " }}"
{{- if .Values.agent.nodeSelector }}
  nodeSelector:
  {{- $local := dict "first" true }}
  {{- range $key, $value := .Values.agent.nodeSelector }}
    {{- if $local.first }} {{ else }},{{ end }}
    {{- $key }}={{ tpl $value $ }}
    {{- $_ := set $local "first" false }}
  {{- end }}
{{- end }}
  nodeUsageMode: "NORMAL"
  podRetention: {{ .Values.agent.podRetention }}
  showRawYaml: true
  serviceAccount: "{{ include "jenkins.serviceAccountAgentName" . }}"
  slaveConnectTimeoutStr: "{{ .Values.agent.connectTimeout }}"
{{- if .Values.agent.volumes }}
  volumes:
  {{- range $index, $volume := .Values.agent.volumes }}
    -{{- if (eq $volume.type "ConfigMap") }} configMapVolume:
     {{- else if (eq $volume.type "EmptyDir") }} emptyDirVolume:
     {{- else if (eq $volume.type "HostPath") }} hostPathVolume:
     {{- else if (eq $volume.type "Nfs") }} nfsVolume:
     {{- else if (eq $volume.type "PVC") }} persistentVolumeClaim:
     {{- else if (eq $volume.type "Secret") }} secretVolume:
     {{- else }} {{ $volume.type }}:
     {{- end }}
    {{- range $key, $value := $volume }}
      {{- if not (eq $key "type") }}
        {{ $key }}: {{ if kindIs "string" $value }}{{ tpl $value $ | quote }}{{ else }}{{ $value }}{{ end }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- if .Values.agent.yamlTemplate }}
  yaml: |-
    {{- tpl (trim .Values.agent.yamlTemplate) . | nindent 4 }}
{{- end }}
  yamlMergeStrategy: {{ .Values.agent.yamlMergeStrategy }}
{{- end -}}

{{- define "jenkins.kubernetes-version" -}}
  {{- if .Values.controller.installPlugins -}}
    {{- range .Values.controller.installPlugins -}}
      {{ if hasPrefix "kubernetes:" . }}
        {{- $split := splitList ":" . }}
        {{- printf "%s" (index $split 1 ) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "jenkins.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "jenkins.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create the name of the service account for Jenkins agents to use
*/}}
{{- define "jenkins.serviceAccountAgentName" -}}
{{- if .Values.serviceAccountAgent.create -}}
    {{ default (printf "%s-%s" (include "jenkins.fullname" .) "agent") .Values.serviceAccountAgent.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccountAgent.name }}
{{- end -}}
{{- end -}}
