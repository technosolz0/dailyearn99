import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"] });

export const metadata = {
  title: "DailyEarn 99 - Play Skill Games & Win Real Cash",
  description: "Download DailyEarn 99 APK and play exciting skill-based games like Image Puzzle, Word Puzzle, Fruit Slicer, and Go Arrows to win real cash daily!",
};

async function getPortfolioConfig() {
  try {
    const apiBase = process.env.NEXT_PUBLIC_API_URL || 'https://api.dailyearn99.in/api';
    const res = await fetch(`${apiBase}/portfolio/config`, { next: { revalidate: 60 } });
    if (res.ok) return await res.json();
  } catch (err) {
    console.error("Error loading layout config:", err);
  }
  return {
    contact_email: "support@dailyearn99.in",
    contact_address: "New Delhi, India"
  };
}

export default async function RootLayout({ children }) {
  const config = await getPortfolioConfig();
  return (
    <html lang="en">
      <body className={inter.className}>
        <header className="header">
          <div className="container nav">
            <div className="logo-container">
              <img src="/app_logo.png" alt="DailyEarn 99 Logo" style={{ height: "40px", width: "auto", borderRadius: "8px" }} />
              <span className="logo-text gradient-text">DailyEarn 99</span>
            </div>
            <ul className="nav-links">
              <li><a href="/" className="nav-link">Home</a></li>
              <li><a href="/#games" className="nav-link">Games</a></li>
              <li><a href="/#referral" className="nav-link">Refer & Earn</a></li>
              <li><a href="/contact" className="nav-link">Contact Us</a></li>
              <li><a href="/#download" className="btn-primary nav-btn">Download APK</a></li>
            </ul>
          </div>
        </header>

        {children}

        <footer className="footer">
          <div className="container footer-grid">
            <div className="footer-col">
              <div style={{ display: "flex", alignItems: "center", gap: "10px", marginBottom: "12px" }}>
                <img src="/app_logo.png" alt="DailyEarn 99 Logo" style={{ height: "36px", width: "auto", borderRadius: "6px" }} />
                <h4 className="gradient-text" style={{ margin: 0 }}>DailyEarn 99</h4>
              </div>
              <p>DailyEarn 99 is India's premier skill-based mobile gaming platform where you can play fun puzzles, test your reflexes, and compete with real players to earn cash prizes.</p>
            </div>
            <div className="footer-col">
              <h4>Quick Links</h4>
              <ul className="footer-links">
                <li><a href="/">Home</a></li>
                <li><a href="/#games">Featured Games</a></li>
                <li><a href="/#referral">Refer & Earn</a></li>
                <li><a href="/contact">Support Center</a></li>
              </ul>
            </div>
            <div className="footer-col">
              <h4>Legal</h4>
              <ul className="footer-links">
                <li><a href="/privacy">Privacy Policy</a></li>
                <li><a href="/terms">Terms & Conditions</a></li>
              </ul>
            </div>
            <div className="footer-col">
              <h4>Contact Us</h4>
              <div className="footer-info">
                <div className="footer-info-item">
                  <span>✉️</span>
                  <span>{config.contact_email || "support@dailyearn99.in"}</span>
                </div>
                <div className="footer-info-item">
                  <span>📍</span>
                  <span>{config.contact_address || "New Delhi, India"}</span>
                </div>
              </div>
            </div>
          </div>

          <div className="container legal-disclaimer">
            <p className="disclaimer-text">
              Disclaimer: DailyEarn 99 is a skill-based gaming platform. The games offered on this platform involve a substantial degree of skill.
              Participation in these contests is subject to our terms and conditions. Players must be 18 years or older and residing in eligible states to play for cash.
              States like Assam, Odisha, Telangana, Sikkim, Nagaland, and Andhra Pradesh do not permit cash skill games; residents of these states are not eligible to participate in cash contests.
            </p>
            <p className="copyright">© 2026 DailyEarn 99. All rights reserved.</p>
          </div>
        </footer>
      </body>
    </html>
  );
}
