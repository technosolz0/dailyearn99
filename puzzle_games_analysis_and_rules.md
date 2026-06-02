# 🎮 target99: Teeno Puzzle Games Ki Complete Analysis, Rules & Status Logic

Yeh document hamare system ke teeno games (**Image Puzzle Game**, **Word Guess Game**, aur **Fruit Slicing Game**) ka ek comprehensive guide hai. Isme **Admin Creation**, **User Play & Earn Flows**, **Gameplay Rules**, **Anti-Cheat Logic** aur **Status Constraints** ko detail mein explain kiya gaya hai.

---

## 📌 1. Games Status Logic (Kab Join & Play Kar Sakte Hain)

Teeno games mein Join karne (Register) aur Play karne (Gameplay Start) ki backend/frontend constraints alag hain:

### 📊 Quick Status Summary Table

| Game Name | Kis Status Pe **Join (Register)** Hoga? | Kis Status Pe **Play (Game Start)** Hoga? |
| :--- | :--- | :--- |
| **🖼️ Image Puzzle** | **`ACTIVE`** ya **`UPCOMING`** | **`ACTIVE`** (registered hone ke baad) |
| **🧩 Word Puzzle** | **`UPCOMING`** (sirf start hone se pehle) | **`ACTIVE`** (registered hone ke baad) |
| **🍎 Fruit Slicing** | **`ACTIVE`** ya **`UPCOMING`** | **`ACTIVE`** (registered hone ke baad) |

---

### 🔍 Detailed Game Wise Rules

#### A. Image Puzzle Game
* **JOIN Logic:** User contest tabhi join kar sakta hai jab database status **`ACTIVE`** ya **`UPCOMING`** ho.
  * *Backend check (`PuzzleGameService.start_puzzle_session`):*
    ```python
    if contest.status != "ACTIVE" and contest.status != "UPCOMING":
        raise ValueError("Contest is not active.")
    ```
* **PLAY Logic:** User tabhi khel sakta hai jab wo registered ho aur current server time contest ke shuru hone ka ho chuka ho (i.e., status **`ACTIVE`** ho). 

#### B. Word Puzzle Game (Special Rules)
* **JOIN Logic (Seat Booking):** Word puzzle mein user sirf tabhi register kar sakta hai jab contest **`UPCOMING`** status mein ho (yaani tournament real-time shuru hone se pehle). Agar contest ek baar `ACTIVE` ho gaya, toh koi naya user join nahi kar sakta.
  * *Backend check (`WordGameService.join_word_contest`):*
    ```python
    if contest.status != "UPCOMING":
        raise ValueError("Contest has already started or completed.")
    ```
* **PLAY Logic:** Contest timing shuru hone par (status transitions to **`ACTIVE`**), registered user `/start` endpoint call karke active questions pull karta hai aur gameplay shuru karta hai.
  * *Backend check (`WordGameService.start_word_contest`):*
    ```python
    if now < contest.start_time or now > contest.end_time:
        raise ValueError("Contest is not active.")
    ```

#### C. Fruit Slicing Tournament
* **JOIN Logic:** User contest tabhi join kar sakta hai jab status **`ACTIVE`** ya **`UPCOMING`** ho.
  * *Backend check (`FruitGameService.start_fruit_session`):*
    ```python
    if contest.status != "ACTIVE" and contest.status != "UPCOMING":
        raise ValueError("Contest is not active.")
    ```
* **PLAY Logic:** Entry fee deduct hone ke baad user active window ke dauran game start kar sakta hai jab state **`ACTIVE`** ho.
  * *Backend check (`start_fruit_contest` API):*
    ```python
    if now < match_record.start_time or now > match_record.end_time:
        raise HTTPException(status_code=400, detail="Contest is not active")
    ```

---

## 🖼️ 2. Image Puzzle Game

### A. Admin Panel Workflow
1. **Contest Setup (`POST /admin/puzzle/contests`):** Admin details provide karta hai: Title, Entry Fee, Total Slots, Prize Pool, Start & End Time, Image URL, aur Grid Size (e.g. 3x3).
2. **Notification Alert:** Server background worker trigger karke push notification bhejta hai.
3. **Contest completion:** Contest end hone par system or admin `complete_puzzle_contest` trigger karta hai.

### B. User Play Flow
1. **Wallet Deduction:** Wallet system se balance cut hota hai (Max 10% from Bonus Wallet, rest from Deposit and Winnings).
2. **Deterministic Layout:** Server grid pieces ko shuffle karke list deta hai (e.g., `[8, 2, 0, 5, 1, 4, 7, 6, 3]`) aur cryptographic HMAC Signature generate karta hai.
3. **Play Mechanics:** User blocks ko slide swap karta hai aur client gameplay telemetry logs record karta hai.

### C. Earning & Calculations
* **Scoring Formula:**
  $$\text{Score} = 10000 - (\text{Seconds} \times 5) - (\text{Moves} \times 2) - (\text{Hints} \times 100)$$
* **Anti-Cheat Playback:** Swaps ke beech minimum 100ms delay mandatory hai (bot block ke liye). Server swap coordinates telemetry ko memory mein playback karke puzzle solution status check karta hai.
* **Payout Logic:** High-score and low-duration ke mutabik players rank kiye jate hain. Ranks ke hisab se cash direct **Winnings Wallet** mein distribute ho jata hai.

---

## 🧩 3. Word Puzzle Game

### A. Admin Panel Workflow
1. **Contest Registry (`POST /admin/word-puzzle/contests`):** Title, Entry Fee, Prize Pool, Start & End time setup.
2. **Bulk Upload Questions (`POST /admin/word-puzzle/questions/bulk/{contest_id}`):** Admin JSON array ke format me questions upload karta hai:
   * `game_type` (WORD_SEARCH, UNSCRAMBLE, MISSING_LETTERS, CROSSWORD)
   * `puzzle_data`, `clues`, `correct_answer`, aur `points_reward`.

### B. User Play Flow
1. **Join Phase:** Status `UPCOMING` hone par entry fee deduct karke register ho jata hai.
2. **Start Phase:** API backend se questions array return karti hai **lekin `correct_answer` ko data se strip (remove) kar diya jata hai** taaki network inspection block ho sake.
3. **Answer submission:** User dynamic inputs submit karta hai one-by-one.

### C. Earning & Calculations
* **Scoring Rules:**
  * Sahi Answer: `+Points Reward` (e.g., +100).
  * Fast Answer Bonus (under 15s): **+50 bonus points**.
  * Galat Answer: **-10 points penalty**.
  * Hint Use: **-20 points penalty**.
* **Anti-Cheat Playback:** 
  * HMAC cryptographic session signatures check hote hain.
  * Server-side timing drift check hota hai. Client aur Server clock mein agar 5s se zyada deviation hai toh sidhe **`DISQUALIFIED`** mark ho jata hai.
* **Payout Logic:** Rank sort parameters: `total_score (desc)` -> `completion_time_seconds (asc)`. Winners ko instant cash winning balance credit.

---

## 🍎 4. Fruit Slicing Game

### A. Admin Panel Workflow
1. **Contest Registry (`POST /admin/fruit-slicing/contests`):** Admin basic game parameters set karta hai.
2. **Deterministic Seed:** Server dynamic unique seed generate karta hai (e.g. `aB3c9X1...`). Yeh seed same format ke dynamic fruit spawning path generate karne ke liye client ko server-side force ki jati hai.

### B. User Play Flow
1. **Lobby Join:** Entry fees deduction process aur user lobby registeration code execution.
2. **Game Play:** deterministic seed aur cryptographic signature return hone par visual Flame/Canvas canvas engine user touch kinematics register karta hai. User 60 seconds swipes generate karta hai.

### C. Earning & Calculations
* **Scoring Rules:**
  * Base Slice: `+10 points`.
  * 3-Fruit Combo: `+20 bonus points`.
  * 5-Fruit Combo: `+50 bonus points`.
  * Bomb Hit: **-100 points** aur current combo streak reset to 0.
  * Fruit Miss: **-5 points penalty**.
* **Anti-Cheat Playback (Kinematics sweep):** 
  * Swipe pixels and timing coordinates space speed calculate ki jati hai. Ek average human standard speed 100 se 25,000 pixels/sec hoti hai. Speed agar 25,000px/s limits cross karti hai toh automation block trigger ho jata hai.
  * Server total slices, combinations, combo streaks aur bomb strikes recalculate karke final score balance match karta hai. Any mismatch marks state as `"SUSPICIOUS"`.
* **Payout Logic:** Rank parameters: `score (desc)` -> `max_combo (desc)` -> `miss_count (asc)` -> `created_at (asc)`. Payouts instant auto credit to wallet.

---

## 📁 5. Important Project Code Map

Aap is core application architecture code ko in files ke zariye direct inspect kar sakte hain:

### 🖥️ Backend Python APIs & Services
* **Image Puzzle API:** [admin_puzzle.py](file:///Volumes/Untitled/aitest/target99/backend/app/api/admin_puzzle.py) & [puzzle_game.py](file:///Volumes/Untitled/aitest/target99/backend/app/api/puzzle_game.py)
* **Word Guess API:** [admin_word.py](file:///Volumes/Untitled/aitest/target99/backend/app/api/admin_word.py) & [word_game.py](file:///Volumes/Untitled/aitest/target99/backend/app/api/word_game.py)
* **Fruit Slice API:** [admin_fruit.py](file:///Volumes/Untitled/aitest/target99/backend/app/api/admin_fruit.py) & [fruit_game.py](file:///Volumes/Untitled/aitest/target99/backend/app/api/fruit_game.py)
* **Core Business logic & Reward Engine:** [services.py](file:///Volumes/Untitled/aitest/target99/backend/app/services.py)

### 📱 Mobile Flutter Lobby Screens (Rules Bottom Sheets)
* **Fruit Lobby:** [fruit_lobby_screen.dart](file:///Volumes/Untitled/aitest/target99/mobile/lib/features/fruit_slicing/screens/fruit_lobby_screen.dart)
* **Puzzle Lobby:** [puzzle_lobby_screen.dart](file:///Volumes/Untitled/aitest/target99/mobile/lib/features/image_puzzle/screens/puzzle_lobby_screen.dart)
* **Word Lobby:** [word_lobby_screen.dart](file:///Volumes/Untitled/aitest/target99/mobile/lib/features/word_puzzle/screens/word_lobby_screen.dart)
