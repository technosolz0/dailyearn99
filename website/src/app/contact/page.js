"use client";

import { useState, useEffect } from "react";

const API_BASE = process.env.NEXT_PUBLIC_API_URL || "https://api.dailyearn99.in/api";

export default function Contact() {
  const [formData, setFormData] = useState({
    name: "",
    email: "",
    subject: "",
    message: ""
  });
  const [loading, setLoading] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [error, setError] = useState(null);

  const [config, setConfig] = useState({
    contact_email: "support@dailyearn99.in",
    contact_phone: "+91 99999 99999",
    contact_address: "DailyEarn 99 Tech Labs Pvt Ltd, Connaught Place, New Delhi, India - 110001",
    office_hours: "Monday - Sunday, 24 Hours Active Online Support"
  });

  useEffect(() => {
    fetch(`${API_BASE}/portfolio/config`)
      .then(res => {
        if (res.ok) return res.json();
        throw new Error("Failed to load contact configuration");
      })
      .then(data => {
        if (data) {
          setConfig(data);
        }
      })
      .catch(err => console.error("Error loading contact config:", err));
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`${API_BASE}/portfolio/contact`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(formData)
      });
      if (!res.ok) throw new Error(await res.text());
      setSubmitted(true);
      setFormData({ name: "", email: "", subject: "", message: "" });
    } catch (err) {
      console.error("Error submitting contact form:", err);
      setError("Failed to submit message. Please check your connection and try again.");
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (e) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value
    });
  };

  return (
    <main style={{ minHeight: "80vh" }}>
      <section className="container contact-section">
        <div style={{ marginBottom: "50px" }}>
          <span className="section-tag">Support Center</span>
          <h1 style={{ fontSize: "36px", fontWeight: "800", marginTop: "8px" }}>Get In Touch With Us</h1>
          <p style={{ color: "var(--text-muted)", marginTop: "12px", maxWidth: "600px" }}>
            Have questions about DailyEarn 99? Need help with withdrawals, deposits, or account details? 
            Fill out the form below or contact us directly. Our support team is active 24/7.
          </p>
        </div>

        <div className="contact-grid">
          {/* Contact Form */}
          <div className="glass-card">
            {submitted ? (
              <div style={{ textAlign: "center", padding: "40px 20px" }}>
                <span style={{ fontSize: "48px", display: "block", marginBottom: "16px" }}>✉️</span>
                <h3 style={{ fontSize: "22px", fontWeight: "bold", marginBottom: "12px" }}>Message Sent Successfully!</h3>
                <p style={{ color: "var(--text-muted)", fontSize: "14px", marginBottom: "24px" }}>
                  Thank you for reaching out. A support representative will review your message and reply via email within the next 2-4 hours.
                </p>
                <button className="btn-primary" onClick={() => setSubmitted(false)}>
                  Send Another Message
                </button>
              </div>
            ) : (
              <form onSubmit={handleSubmit}>
                <div className="form-group">
                  <label className="form-label" htmlFor="name">Your Name</label>
                  <input
                    type="text"
                    id="name"
                    name="name"
                    className="form-input"
                    placeholder="Enter your name"
                    value={formData.name}
                    onChange={handleChange}
                    required
                  />
                </div>

                <div className="form-group">
                  <label className="form-label" htmlFor="email">Email Address</label>
                  <input
                    type="email"
                    id="email"
                    name="email"
                    className="form-input"
                    placeholder="Enter your email address"
                    value={formData.email}
                    onChange={handleChange}
                    required
                  />
                </div>

                <div className="form-group">
                  <label className="form-label" htmlFor="subject">Subject</label>
                  <input
                    type="text"
                    id="subject"
                    name="subject"
                    className="form-input"
                    placeholder="How can we help you?"
                    value={formData.subject}
                    onChange={handleChange}
                    required
                  />
                </div>

                <div className="form-group">
                  <label className="form-label" htmlFor="message">Message</label>
                  <textarea
                    id="message"
                    name="message"
                    className="form-textarea"
                    placeholder="Write details of your query here..."
                    value={formData.message}
                    onChange={handleChange}
                    required
                  />
                </div>

                {error && (
                  <p style={{ color: "red", fontSize: "13px", marginTop: "-10px", marginBottom: "15px", textAlign: "center" }}>
                    {error}
                  </p>
                )}
                <button type="submit" className="btn-primary" style={{ width: "100%", justifyContent: "center" }} disabled={loading}>
                  {loading ? "Sending Message..." : "Send Message"}
                </button>
              </form>
            )}
          </div>

          {/* Contact Details Column */}
          <div className="glass-card contact-info-card">
            <h3 style={{ fontSize: "20px", fontWeight: "800", marginBottom: "30px" }}>Contact Details</h3>

            <div className="contact-method">
              <div className="contact-icon-bg">✉️</div>
              <div>
                <h4>Email Support</h4>
                <p>{config.contact_email || "support@dailyearn99.in"}</p>
                <p style={{ fontSize: "12px", marginTop: "4px" }}>Response time: Under 4 hours</p>
              </div>
            </div>

            <div className="contact-method">
              <div className="contact-icon-bg">📍</div>
              <div>
                <h4>Office Location</h4>
                <p style={{ whiteSpace: "pre-line" }}>{config.contact_address || "DailyEarn 99 Tech Labs Pvt Ltd\nConnaught Place, New Delhi\nIndia - 110001"}</p>
              </div>
            </div>

            <div className="contact-method">
              <div className="contact-icon-bg">⏱️</div>
              <div>
                <h4>Working Hours</h4>
                <p style={{ whiteSpace: "pre-line" }}>{config.office_hours || "Monday - Sunday\n24 Hours Active Online Support"}</p>
              </div>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
