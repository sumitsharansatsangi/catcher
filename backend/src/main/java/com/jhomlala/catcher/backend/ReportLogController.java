package com.jhomlala.catcher.backend;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;

@Controller
public class ReportLogController {

	@Autowired
	private ReportLogService reportLogService;
	
	@RequestMapping(value = "/report", method = RequestMethod.POST)
	@ResponseStatus(value = HttpStatus.OK)
	public void handleReportLog(@RequestBody ReportLog reportLog) {
		reportLogService.addReportLog(reportLog);
	}

	@RequestMapping(value = "/reports", method = RequestMethod.GET)
	public String reportsPage(
			@RequestParam(value = "severity", required = false) String severity,
			@RequestParam(value = "platform", required = false) String platform,
			@RequestParam(value = "status", required = false) String status,
			@RequestParam(value = "query", required = false) String query,
			Model model) {
		List<ReportLog> reportsCopied = new ArrayList<ReportLog>(reportLogService.getReportLogs());
		reportsCopied.removeIf(report -> !matches(report, severity, platform, status, query));
		Collections.reverse(reportsCopied);
		model.addAttribute("reportLogs",reportsCopied);
		model.addAttribute("severity", severity);
		model.addAttribute("platform", platform);
		model.addAttribute("status", status);
		model.addAttribute("query", query);
		return "reports";
	}

	private boolean matches(ReportLog report, String severity, String platform, String status, String query) {
		if (severity != null && !severity.isBlank() && !severity.equalsIgnoreCase(report.getSeverity())) {
			return false;
		}
		if (platform != null && !platform.isBlank() && !platform.equalsIgnoreCase(report.getPlatformType())) {
			return false;
		}
		if (status != null && !status.isBlank() && !status.equalsIgnoreCase(report.getStatus())) {
			return false;
		}
		if (query != null && !query.isBlank()) {
			String text = (report.getError() + " " + report.getFingerprint()).toLowerCase();
			return text.contains(query.toLowerCase());
		}
		return true;
	}

}
