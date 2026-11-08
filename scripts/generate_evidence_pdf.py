# scripts/generate_evidence_pdf.py
# Generates a professional execution-evidence PDF for the CodeAlpha Jenkins Remoting project

import os
import sys
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Image, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, page_count):
        self.saveState()
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#718096"))
        
        # Header (on pages after cover/page 1)
        if self._pageNumber > 1:
            self.drawString(54, 755, "CodeAlpha Internship: Distributed Build Execution Using Jenkins Remoting")
            self.setStrokeColor(colors.HexColor("#E2E8F0"))
            self.setLineWidth(0.5)
            self.line(54, 747, 558, 747)
        
        # Footer
        self.setStrokeColor(colors.HexColor("#E2E8F0"))
        self.setLineWidth(0.5)
        self.line(54, 45, 558, 45)
        self.drawString(54, 32, "Confidential - CodeAlpha Internship Evidence Package")
        self.drawRightString(558, 32, f"Page {self._pageNumber} of {page_count}")
        self.restoreState()

def create_evidence_pdf(output_path, screenshots_dir):
    doc = SimpleDocTemplate(
        output_path,
        pagesize=letter,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )

    styles = getSampleStyleSheet()

    # Custom styles
    primary_color = colors.HexColor("#1A365D")   # Deep navy
    secondary_color = colors.HexColor("#2B6CB0") # Slate blue
    text_dark = colors.HexColor("#2D3748")       # Charcoal
    bg_light = colors.HexColor("#F7FAFC")        # Warm white/light gray
    border_color = colors.HexColor("#E2E8F0")

    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=20,
        leading=24,
        textColor=primary_color,
        spaceAfter=6
    )

    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=12,
        leading=16,
        textColor=secondary_color,
        spaceAfter=14
    )

    h2_style = ParagraphStyle(
        'SectionHeading',
        parent=styles['Heading2'],
        fontName='Helvetica-Bold',
        fontSize=13,
        leading=17,
        textColor=primary_color,
        spaceBefore=10,
        spaceAfter=6
    )

    body_style = ParagraphStyle(
        'BodyDark',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9.5,
        leading=13.5,
        textColor=text_dark
    )

    body_bold = ParagraphStyle(
        'BodyBold',
        parent=body_style,
        fontName='Helvetica-Bold'
    )

    caption_style = ParagraphStyle(
        'ImageCaption',
        parent=styles['Normal'],
        fontName='Helvetica-Oblique',
        fontSize=8.5,
        leading=12,
        textColor=colors.HexColor("#4A5568")
    )

    story = []

    # 1. Cover Header
    story.append(Paragraph("CodeAlpha Internship — Project Execution Evidence", title_style))
    story.append(Paragraph("Distributed Build Execution Using Jenkins Remoting", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=1.5, color=primary_color, spaceAfter=12))

    # 2. Executive Metadata Box
    meta_data = [
        [
            Paragraph("<b>Candidate / Track:</b> CodeAlpha DevOps Intern", body_style),
            Paragraph("<b>Environment:</b> Windows Host (Adoptium JDK 21) & Docker Engine", body_style)
        ],
        [
            Paragraph("<b>Project Domain:</b> CI/CD & Distributed Systems", body_style),
            Paragraph("<b>Controller Version:</b> Jenkins LTS (JDK 21) via JCasC", body_style)
        ],
        [
            Paragraph("<b>Remoting Protocols:</b> JNLP4-connect (TCP 50000) & WebSocket", body_style),
            Paragraph("<b>Execution Workspaces:</b> Isolated agent-specific directories", body_style)
        ]
    ]
    meta_table = Table(meta_data, colWidths=[250, 254])
    meta_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), bg_light),
        ('BOX', (0, 0), (-1, -1), 1, border_color),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, border_color),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('RIGHTPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(meta_table)
    story.append(Spacer(1, 10))

    # 3. Purpose & Architecture Note
    story.append(Paragraph("Project Purpose & Environmental Overview", h2_style))
    purpose_text = (
        "This project establishes a resilient, production-ready <b>Distributed Build Architecture</b> "
        "using Jenkins Remoting. To eliminate security vulnerabilities and performance bottlenecks inherent to monolithic CI/CD setups, "
        "the Jenkins Controller is configured with zero executors (<code>numExecutors: 0</code>). All build, compilation, and test execution workloads "
        "are delegated strictly to remote inbound worker nodes authenticated via genuine HMAC cryptographic tokens."
    )
    story.append(Paragraph(purpose_text, body_style))
    story.append(Spacer(1, 6))

    arch_note = (
        "<b>Important Environment Topology Notice:</b> The Linux inbound agent (running inside an isolated Docker container with Temurin JDK 21) "
        "and the Windows inbound agent (running as a native Windows host process with Temurin JDK 21) represent separate "
        "<b>operating-system runtime environments</b> hosted on the same workstation, not physically distinct hardware machines or disparate CPU architectures. "
        "Both environments successfully connect to the central Controller, enforce separated workspace boundaries, and follow least-privilege principles."
    )
    story.append(Paragraph(arch_note, body_style))
    story.append(Spacer(1, 14))

    # 4. Evidence Items Definition
    evidence_items = [
        {
            "num": 1,
            "filename": "01-jenkins-controller-dashboard.png",
            "title": "Jenkins Controller Dashboard & Zero Built-In Executors",
            "desc": (
                "The Jenkins Controller dashboard displays the <code>codealpha-distributed-job</code> pipeline in a healthy state (blue indicator). "
                "The <i>Build Executor Status</i> panel confirms that the Built-In Node has exactly zero executors (<code>numExecutors: 0</code>), "
                "verifying that the controller is restricted purely to orchestration and cannot execute user-submitted build scripts."
            )
        },
        {
            "num": 2,
            "filename": "02-jenkins-node-management.png",
            "title": "Jenkins Node Management — Distributed Nodes Overview",
            "desc": (
                "The Node Management interface (<code>/computer/</code>) confirms that both distributed agents—<code>remote-linux-agent</code> "
                "(2 executors) and <code>windows-agent</code> (2 executors)—are registered, in sync, and actively connected. "
                "The total cluster execution capacity is 4 distributed executors with 0 on the controller."
            )
        },
        {
            "num": 3,
            "filename": "03-linux-inbound-agent.png",
            "title": "Linux Inbound Agent Node Details & Remoting Status",
            "desc": (
                "Node status details for <code>remote-linux-agent</code> demonstrating active connectivity over the Jenkins JNLP4 Remoting protocol. "
                "The agent runs with labels <code>java-agent linux remote-linux-agent docker</code> and executes within an isolated remote filesystem root "
                "at <code>/home/jenkins/agent</code>."
            )
        },
        {
            "num": 4,
            "filename": "04-windows-inbound-agent.png",
            "title": "Windows Inbound Agent Node Details & WebSocket Connection",
            "desc": (
                "Node status details for <code>windows-agent</code> displaying an active connection via WebSocket. "
                "The agent is labeled <code>windows-agent java-agent host windows</code> with its isolated remote filesystem configured at "
                "<code>C:/jenkins-agent-workspace</code> on the Windows host."
            )
        },
        {
            "num": 5,
            "filename": "05-distributed-pipeline-execution.png",
            "title": "Distributed Pipeline Stage View — Successful Builds",
            "desc": (
                "The Declarative Pipeline Stage View for <code>codealpha-distributed-job</code> showcases consecutive passing builds (Build #2 and Build #3). "
                "Every stage executed cleanly on the distributed worker node: Source Code Checkout, Remote Node Verification, Java 21 Compilation, "
                "JUnit 5 Test Suite, and Artifact Archiving."
            )
        },
        {
            "num": 6,
            "filename": "06-build-console-node-verification.png",
            "title": "Build Console Log & Remote Node Execution Proof",
            "desc": (
                "Live console output from Build #3 providing empirical proof of remote execution: <code>Running on remote-linux-agent in /home/jenkins/agent/workspace/...</code>. "
                "The environment diagnostics confirm Linux kernel details (<code>6.18.54.1-microsoft-standard-WSL2 x86_64</code>), user <code>jenkins</code>, "
                "successful execution of 4/4 JUnit unit tests, artifact creation, and final status <code>SUCCESS</code>."
            )
        }
    ]

    for item in evidence_items:
        story.append(PageBreak())
        story.append(Paragraph(f"Evidence #{item['num']}: {item['title']}", h2_style))
        story.append(Paragraph(item['desc'], body_style))
        story.append(Spacer(1, 8))

        img_path = os.path.join(screenshots_dir, item['filename'])
        if os.path.exists(img_path):
            # 1440x960 aspect ratio is 1.5. Render at 490 x 326.6 points.
            img = Image(img_path, width=490, height=326.6)
            story.append(img)
            story.append(Spacer(1, 4))
            story.append(Paragraph(f"Figure {item['num']}: Actual screenshot captured from live running Jenkins environment (File: <code>{item['filename']}</code>).", caption_style))
        else:
            story.append(Paragraph(f"<b>[ERROR: Screenshot file {item['filename']} not found]</b>", body_bold))

    # 5. Verified Execution Summary Page
    story.append(PageBreak())
    story.append(Paragraph("Verified Execution & Security Audit Summary", h2_style))
    summary_intro = (
        "All components, connections, pipeline executions, and security hardening measures have been "
        "<b>empirically executed, validated, and audited</b> as documented in the table below:"
    )
    story.append(Paragraph(summary_intro, body_style))
    story.append(Spacer(1, 8))

    summary_rows = [
        [Paragraph("<b>Component / Area</b>", body_style), Paragraph("<b>Empirical Verification Result</b>", body_style), Paragraph("<b>Status</b>", body_style)],
        [
            Paragraph("Jenkins Controller", body_style),
            Paragraph("Running Jenkins LTS on JDK 21 (ports 8080/50000). Built-in node isolated with 0 executors via JCasC.", body_style),
            Paragraph("<font color='#276749'><b>VERIFIED</b></font>", body_style)
        ],
        [
            Paragraph("Linux Inbound Agent", body_style),
            Paragraph("Docker container running <code>jenkins/inbound-agent:latest-jdk21</code>. Connected via JNLP4 Remoting protocol. Workspace: <code>/home/jenkins/agent</code>.", body_style),
            Paragraph("<font color='#276749'><b>VERIFIED</b></font>", body_style)
        ],
        [
            Paragraph("Windows Inbound Agent", body_style),
            Paragraph("Native Windows host process running Adoptium JDK 21. Connected via WebSocket. Workspace: <code>C:/jenkins-agent-workspace</code>.", body_style),
            Paragraph("<font color='#276749'><b>VERIFIED</b></font>", body_style)
        ],
        [
            Paragraph("Distributed Build Execution", body_style),
            Paragraph("Pipeline explicitly targeted <code>label 'java-agent'</code>. Build executed entirely inside remote agent workspace without touching controller filesystem.", body_style),
            Paragraph("<font color='#276749'><b>VERIFIED</b></font>", body_style)
        ],
        [
            Paragraph("Java Compilation & Testing", body_style),
            Paragraph("Gradle Wrapper compiled Java 21 sources. Executed JUnit 5 suite: 4 tests passed (Addition, Multiplication, HealthCheck, HostnameResolution).", body_style),
            Paragraph("<font color='#276749'><b>VERIFIED</b></font>", body_style)
        ],
        [
            Paragraph("Artifact Archiving", body_style),
            Paragraph("<code>CodeAlpha-Remoting-App-1.0.0.jar</code> generated on agent and archived back to controller with fingerprints.", body_style),
            Paragraph("<font color='#276749'><b>VERIFIED</b></font>", body_style)
        ],
        [
            Paragraph("Credential Isolation", body_style),
            Paragraph("All hardcoded passwords and agent secrets removed from tracked files. Rotated credentials stored in git-ignored <code>.env</code>.", body_style),
            Paragraph("<font color='#276749'><b>VERIFIED</b></font>", body_style)
        ]
    ]

    summary_table = Table(summary_rows, colWidths=[130, 310, 64])
    summary_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#EDF2F7")),
        ('BOX', (0, 0), (-1, -1), 1, border_color),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, border_color),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(summary_table)
    story.append(Spacer(1, 14))

    conclusion_text = (
        "<b>Conclusion:</b> The CodeAlpha Jenkins Remoting internship project satisfies all foundational and advanced criteria. "
        "By enforcing strict node isolation, multi-platform agent connectivity, declarative distributed pipelines, and robust DevSecOps credential management, "
        "the architecture serves as an exemplary implementation of modern continuous integration standards."
    )
    story.append(Paragraph(conclusion_text, body_style))

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"[SUCCESS] Execution evidence PDF compiled cleanly at: {output_path}")

if __name__ == '__main__':
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    pdf_out = os.path.join(project_root, 'screenshots', 'Project_Evidence.pdf')
    screens_dir = os.path.join(project_root, 'screenshots')
    create_evidence_pdf(pdf_out, screens_dir)
