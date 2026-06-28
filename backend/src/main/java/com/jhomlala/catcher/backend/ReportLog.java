package com.jhomlala.catcher.backend;

import java.sql.Timestamp;
import java.util.Map;
import java.util.Map.Entry;

public class ReportLog {
	private String error;
	private String stackTrace;
	private String severity;
	private String fingerprint;
	private String platformType;
	private String status = "open";
	private Map<String,String> deviceParameters;
	private Map<String,String> applicationParameters;
	private Map<String,String> customParameters;
	private Map<String,String> tags;
	private Map<String,String> extras;
	private Map<String,String> user;
	private Timestamp dateTime;
	public String getError() {
		return error;
	}
	public void setError(String error) {
		this.error = error;
	}
	public String getStackTrace() {
		return stackTrace;
	}
	public void setStackTrace(String stackTrace) {
		this.stackTrace = stackTrace;
	}
	public String getSeverity() {
		return severity;
	}
	public void setSeverity(String severity) {
		this.severity = severity;
	}
	public String getFingerprint() {
		return fingerprint;
	}
	public void setFingerprint(String fingerprint) {
		this.fingerprint = fingerprint;
	}
	public String getPlatformType() {
		return platformType;
	}
	public void setPlatformType(String platformType) {
		this.platformType = platformType;
	}
	public String getStatus() {
		return status;
	}
	public void setStatus(String status) {
		this.status = status;
	}
	public Map<String, String> getDeviceParameters() {
		return deviceParameters;
	}
	public void setDeviceParameters(Map<String, String> deviceParameters) {
		this.deviceParameters = deviceParameters;
	}
	public Map<String, String> getApplicationParameters() {
		return applicationParameters;
	}
	public void setApplicationParameters(Map<String, String> applicationParameters) {
		this.applicationParameters = applicationParameters;
	}
	public Map<String, String> getCustomParameters() {
		return customParameters;
	}
	public void setCustomParameters(Map<String, String> customParameters) {
		this.customParameters = customParameters;
	}
	public Map<String, String> getTags() {
		return tags;
	}
	public void setTags(Map<String, String> tags) {
		this.tags = tags;
	}
	public Map<String, String> getExtras() {
		return extras;
	}
	public void setExtras(Map<String, String> extras) {
		this.extras = extras;
	}
	public Map<String, String> getUser() {
		return user;
	}
	public void setUser(Map<String, String> user) {
		this.user = user;
	}
	
	public Timestamp getDateTime() {
		return dateTime;
	}
	public void setDateTime(Timestamp dateTime) {
		this.dateTime = dateTime;
	}
	@Override
	public String toString() {
		return "ReportLog [error=" + error + ", severity=" + severity + ", fingerprint=" + fingerprint
				+ ", platformType=" + platformType + ", status=" + status + ", stackTrace=" + stackTrace + ", deviceParameters=" + deviceParameters
				+ ", applicationParameters=" + applicationParameters + ", customParameters=" + customParameters
				+ ", dateTime=" + dateTime + "]";
	}
	
	public String getStackTraceFormatted() {
		if (stackTrace == null) {
			return "";
		}
		return "<small>"+stackTrace.replace("\n", "<br>")+"</small>";
	}
	
	public String getDeviceDataFormatted() {
		return getMapFormatted(deviceParameters);
	}

	public String getTagsFormatted() {
		return getMapFormatted(tags);
	}

	public String getUserFormatted() {
		return getMapFormatted(user);
	}

	private String getMapFormatted(Map<String, String> values) {
		if (values == null || values.isEmpty()) {
			return "";
		}
		String text = "<small>";
		for (Entry<String, String> entry: values.entrySet()) {
			text += "<b>"+entry.getKey()+"</b>: "+entry.getValue() +"<br>";
		}
		text += "</small>";
		return text;
	}
	
	
}
