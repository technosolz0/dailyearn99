"use client";

import { useState, useEffect } from "react";

const API_BASE = process.env.NEXT_PUBLIC_API_URL || "https://api.dailyearn99.in/api";

export default function Home() {
  const [copied, setCopied] = useState(false);
  const [activeFaq, setActiveFaq] = useState(null);
  const [isSpinning, setIsSpinning] = useState(false);

  const [config, setConfig] = useState({
    apk_link: "https://play.google.com/store/apps/details?id=com.dailyearn99.dailyearn99",
    referral_code: "DAILYEARN99"
  });

  useEffect(() => {
    fetch(`${API_BASE}/portfolio/config`)
      .then(res => {
        if (res.ok) return res.json();
        throw new Error("Failed to fetch config");
      })
      .then(data => {
        if (data) {
          setConfig(data);
        }
      })
      .catch(err => console.error("Error loading portfolio config:", err));
  }, []);

  const referralCode = config.referral_code || "DAILYEARN99";

  const handleCopy = () => {
    navigator.clipboard.writeText(referralCode);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const toggleFaq = (index) => {
    if (activeFaq === index) {
      setActiveFaq(null);
    } else {
      setActiveFaq(index);
    }
  };

  const triggerMockSpin = () => {
    if (isSpinning) return;
    setIsSpinning(true);
    setTimeout(() => {
      setIsSpinning(false);
    }, 4000);
  };

  const faqs = [
    {
      q: "Is DailyEarn 99 legal in India?",
      a: "Yes, absolutely! DailyEarn 99 offers games of skill (like Image Puzzles, Word Puzzles, and Go Arrows) where player outcomes depend on their memory, focus, and speed rather than luck. According to Indian federal laws, playing skill games for real money is 100% legal, except in states that restrict all real-money games (such as Assam, Odisha, Telangana, Sikkim, Nagaland, and Andhra Pradesh)."
    },
    {
      q: "How can I withdraw my winnings?",
      a: "Winnings can be withdrawn instantly to your Bank Account or via UPI. Go to the 'Wallet' tab in the app, link your details, enter your withdrawal amount, and tap withdraw. Most withdrawals are processed instantly or within 24 hours."
    },
    {
      q: "How does the Referral Bonus program work?",
      a: "When you refer a friend, they get ₹20 instantly upon sign-up. Once they deposit and play their first cash contest, you will receive a ₹50 cash bonus in your wallet. There is no limit to the number of friends you can refer!"
    },
    {
      q: "Is my money safe on DailyEarn 99?",
      a: "Yes. All deposits and transactions are encrypted with SSL protocols. We partner with secure payment gateways (like Razorpay/Cashfree) to facilitate safe transactions, and we adhere to strict fair play policies to prevent fraud."
    }
  ];

  return (
    <main style={{ minHeight: "100vh" }}>
      {/* Hero Section */}
      <section className="container hero-section">
        <div className="hero-content">
          <span className="section-tag">Welcome to the Future of Gaming</span>
          <h1>
            Play Skill Games.<br />
            <span className="gradient-text">Win Real Cash Daily.</span>
          </h1>
          <p>
            Put your puzzle-solving skills, vocabulary, and reflexes to the test. Join cash contests, beat the live leaderboards, and withdraw winnings instantly.
          </p>

          <div className="hero-ctas" id="download">
            <a href={config.apk_link} className="btn-primary" download>
              <span>📥</span> Download Android APK
            </a>
            <a href="#games" className="btn-secondary">
              Explore Games
            </a>
          </div>

          {/* Referral Widget */}
          <div className="referral-widget" id="referral">
            <div>
              <h3 style={{ fontSize: '16px', fontWeight: 'bold', marginBottom: '4px' }}>🎁 Special Registration Offer!</h3>
              <p style={{ color: 'var(--text-muted)', fontSize: '13px' }}>Use the code below during sign up to get a <strong>₹20 Cash Bonus</strong> instantly!</p>
            </div>
            <div className="ref-code-box">
              <span className="ref-code">{referralCode}</span>
              <button className="ref-copy-btn" onClick={handleCopy}>
                {copied ? "Copied! ✓" : "Copy Code"}
              </button>
            </div>
          </div>
        </div>

        <div className="hero-image">
          <div className="phone-mockup">
            <div className="phone-screen">
              <div className="phone-header">
                <span>📶 LTE</span>
                <span>DailyEarn 99</span>
                <span>🔋 99%</span>
              </div>

              <div className="phone-wheel-container">
                <span style={{ fontSize: '14px', fontWeight: 'bold', color: 'var(--accent-cyan)' }}>Wheel of Multipliers</span>
                <div
                  className="dummy-wheel"
                  style={{
                    transform: isSpinning ? "rotate(1440deg)" : "rotate(0deg)",
                    transition: isSpinning ? "transform 4s cubic-bezier(0.1, 0.8, 0.1, 1)" : "none"
                  }}
                  onClick={triggerMockSpin}
                >
                  <div className="dummy-wheel-pin"></div>
                </div>
                <button
                  className="btn-primary"
                  style={{ padding: '8px 16px', fontSize: '12px', borderRadius: '8px' }}
                  onClick={triggerMockSpin}
                  disabled={isSpinning}
                >
                  {isSpinning ? "Spinning..." : "Tap to Spin!"}
                </button>
              </div>

              <div className="phone-card" style={{ display: 'flex', justifyContent: 'space-between', fontSize: '11px' }}>
                <div>
                  <span style={{ color: 'var(--text-muted)', display: 'block', fontSize: '9px' }}>WALLET BALANCE</span>
                  <strong style={{ color: 'var(--accent-emerald)', fontSize: '14px' }}>₹1,540.00</strong>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <span style={{ color: 'var(--text-muted)', display: 'block', fontSize: '9px' }}>TOTAL WINNINGS</span>
                  <strong style={{ color: 'var(--accent-cyan)', fontSize: '14px' }}>₹12,450.00</strong>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Games Showcase Section */}
      <section id="games" style={{ background: '#0D111D', padding: '80px 0', borderTop: '1px solid var(--border-col)', borderBottom: '1px solid var(--border-col)' }}>
        <div className="container">
          <div className="section-title-wrap">
            <span className="section-tag">Skill Based Arcade & Puzzles</span>
            <h2 className="section-title">Explore Our Games</h2>
          </div>

          <div className="games-grid">
            {/* Image Puzzle */}
            <div className="glass-card">
              <span className="game-icon">🧩</span>
              <h3 style={{ fontSize: '18px', fontWeight: 'bold', marginBottom: '8px' }}>Image Puzzle</h3>
              <p style={{ color: 'var(--text-muted)', fontSize: '14px', lineHeight: '1.6', marginBottom: '16px' }}>
                Re-arrange scrambled picture tiles to solve the puzzle before the timer runs out. Fast thinking and spatial awareness are key!
              </p>
              <span style={{ color: 'var(--accent-cyan)', fontSize: '12px', fontWeight: 'bold' }}>🎮 PLAY & WIN CASH →</span>
            </div>

            {/* Word Puzzle */}
            <div className="glass-card">
              <span className="game-icon">🔤</span>
              <h3 style={{ fontSize: '18px', fontWeight: 'bold', marginBottom: '8px' }}>Word Puzzle</h3>
              <p style={{ color: 'var(--text-muted)', fontSize: '14px', lineHeight: '1.6', marginBottom: '16px' }}>
                Unscramble mixed-up letters and fill in the missing blanks. Test your vocabulary speed to top the contest leaderboard.
              </p>
              <span style={{ color: 'var(--accent-purple)', fontSize: '12px', fontWeight: 'bold' }}>🎮 PLAY & WIN CASH →</span>
            </div>

            {/* Fruit Slicing */}
            <div className="glass-card">
              <span className="game-icon">🍎</span>
              <h3 style={{ fontSize: '18px', fontWeight: 'bold', marginBottom: '8px' }}>Fruit Slicer</h3>
              <p style={{ color: 'var(--text-muted)', fontSize: '14px', lineHeight: '1.6', marginBottom: '16px' }}>
                Swipe to slice high-scoring fruits, create multiplier combos, and avoid the explosive bombs. Keep your reflexes sharp!
              </p>
              <span style={{ color: 'var(--accent-emerald)', fontSize: '12px', fontWeight: 'bold' }}>🎮 PLAY & WIN CASH →</span>
            </div>

            {/* Go Arrows */}
            <div className="glass-card">
              <span className="game-icon">🏹</span>
              <h3 style={{ fontSize: '18px', fontWeight: 'bold', marginBottom: '8px' }}>Go Arrows</h3>
              <p style={{ color: 'var(--text-muted)', fontSize: '14px', lineHeight: '1.6', marginBottom: '16px' }}>
                Tap blocks in the direction of their arrows to make them fly off-screen. Evade obstacles and resolve alignments to win.
              </p>
              <span style={{ color: 'var(--accent-pink)', fontSize: '12px', fontWeight: 'bold' }}>🎮 PLAY & WIN CASH →</span>
            </div>
          </div>
        </div>
      </section>

      {/* Refer & Earn Section */}
      <section style={{ padding: '80px 0' }}>
        <div className="container">
          <div className="section-title-wrap">
            <span className="section-tag">Referral Program</span>
            <h2 className="section-title">How the Referral Program Works</h2>
          </div>

          <div className="steps-grid">
            <div className="step-card">
              <div className="step-num">1</div>
              <h3>Share Code</h3>
              <p>Send your unique referral code or link to your friends from the app profile page.</p>
            </div>
            <div className="step-card">
              <div className="step-num">2</div>
              <h3>Friend Registers</h3>
              <p>Your friend registers on DailyEarn 99 using your code and gets an instant ₹20 sign-up bonus.</p>
            </div>
            <div className="step-card">
              <div className="step-num">3</div>
              <h3>Get Paid</h3>
              <p>As soon as your friend plays their first cash contest, ₹50 cash is credited to your wallet!</p>
            </div>
          </div>
        </div>
      </section>

      {/* FAQ Section */}
      <section style={{ padding: '80px 0', background: '#0D111D', borderTop: '1px solid var(--border-col)' }}>
        <div className="container">
          <div className="section-title-wrap">
            <span className="section-tag">Got Questions?</span>
            <h2 className="section-title">Frequently Asked Questions</h2>
          </div>

          <div className="faq-grid">
            {faqs.map((faq, index) => (
              <div key={index} className="faq-card" onClick={() => toggleFaq(index)}>
                <div className="faq-question">
                  <span>{faq.q}</span>
                  <span>{activeFaq === index ? "−" : "+"}</span>
                </div>
                {activeFaq === index && (
                  <div className="faq-answer">
                    {faq.a}
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      </section>
    </main>
  );
}
