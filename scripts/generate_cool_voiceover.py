import asyncio
import os
import shutil
import edge_tts

# Casual, cool script rewritten for a conversational, energetic, and engaging presentation style
CASUAL_SCRIPTS = {
    "slide1_cover": (
        "Hey everyone! We're Team Binary Duo, and this is GlycoLens. "
        "We built an AI that gives people with Type 1 Diabetes early warnings before their blood sugar crashes, "
        "and calculates meal carbs the way Indian families actually eat—in rotis and katoris, not grams."
    ),
    "slide2_problem": (
        "So here's the reality: over 850,000 people in India live with Type 1 Diabetes. "
        "Every day, they walk a tightrope with insulin. Take just a little too much, and blood sugar crashes into severe hypoglycemia. "
        "Now, existing CGM monitors like Dexcom or Libre only beep AFTER you've already dropped below 70. "
        "By then, you're already trembling and feeling sick. That's reactive, not preventative! "
        "On top of that, Western food apps ask for 120 grams of cooked lentils or raw flour weight. "
        "Nobody brings a digital kitchen scale to a family dinner table! We eat in rotis and bowls. "
        "So patients end up guessing, leading to bad crashes and emergency room visits."
    ),
    "slide3_solution": (
        "That's exactly why we built GlycoLens around two core ideas. "
        "First, a smart PyTorch LSTM neural network that looks at your real-time glucose speed and active insulin "
        "to predict where your sugar will be 30 and 60 minutes ahead of time. "
        "Second, a cultural Indian meal estimator mapped to official ICMR nutrition tables. "
        "You log your food in simple rotis and standard 9-centimeter katoris, and it calculates net carbs and glycemic load instantly. "
        "Let's check out the prototype live on my phone."
    ),
    "slide4_features": (
        "Here's what makes it clinically solid: "
        "Our dynamic glucose gauge tracks rate-of-change with a 90% confidence cone, so you can see trends at a glance. "
        "When blood sugar drops, the app kicks in the clinical Rule of 15: "
        "it tells you to take 15 grams of fast carbs and starts a 15-minute timer so you don't panic-binge and spike back up. "
        "Plus, you can log food either by tapping portions or snapping a photo with AI tableware detection. "
        "And because safety comes first, GlycoLens is designed as non-device clinical decision support following CDSCO guidelines."
    ),
    "slide5_livedemo": (
        "Now let's see the app running live on my phone. "
        "Right now, the dial is sitting at 110 in the green zone, showing plus 30 and plus 60-minute predictions. "
        "Now watch what happens when I hit 'Post-Meal Low' to simulate a drop. "
        "In less than 15 milliseconds, the AI catches the downward trend. "
        "My phone immediately vibrates, and look at the lockscreen notification: "
        "'Hypo Warning: Predicted in 38 minutes. Glucose dropping to 58. Eat a fruit or 15 grams of carbs now!' "
        "The patient gets alerted way before feeling dizzy. "
        "Now for lunch: I tap 2 Rotis, 1 Katori Dal, and 1 Katori Rice. "
        "It instantly figures out 59.7 grams of net carbs, logs it to SQLite, and updates the glucose curve. "
        "Clean, instant, and effortless."
    ),
    "slide6_architecture": (
        "Under the hood, we built a lean, high-speed stack: "
        "Our frontend is a Flutter Progressive Web App with a custom Network-First service worker and native Web Push Notifications. "
        "The backend runs on Python FastAPI and SQLite, hitting response times under 15 milliseconds. "
        "Our PyTorch LSTM model hits a tight RMSE of 12.5 mg/dL. "
        "And for computer vision, we fine-tuned YOLOv8 calibrated to a standard 9-centimeter steel katori."
    ),
    "slide7_impact": (
        "Looking at the bigger picture: "
        "Giving patients a 30 to 60-minute heads-up prevents emergency room visits, saving families anywhere from 15,000 to 50,000 rupees each time. "
        "Ditching the kitchen scale boosts meal logging adherence from under 20% to over 85%. "
        "Next on our roadmap: direct Bluetooth pairing with Dexcom and FreeStyle Libre sensors, "
        "voice logging in Hindi, Tamil, Telugu, and Marathi, and automated WhatsApp alerts for parents when a kid's sugar drops."
    ),
    "slide8_conclusion": (
        "To wrap it up: Managing diabetes shouldn't feel like a math exam, and nobody should have to live in fear of a sudden low. "
        "GlycoLens brings proactive AI forecasting and real Indian nutrition straight to your pocket. "
        "Thanks so much for listening! We're Team Binary Duo, and we'd love to take your questions."
    ),
}

async def generate_cool_voiceovers():
    docs_audio_dir = "docs/audio"
    web_audio_dir = "mobile/build/web/audio"
    os.makedirs(docs_audio_dir, exist_ok=True)
    os.makedirs(web_audio_dir, exist_ok=True)

    # Voice 1: Brian (Cool, energetic, young tech founder / creator voice)
    voice = "en-US-BrianNeural"
    rate = "+1%"

    print(f"--- Generating Cool Casual Voiceover with {voice} ---")
    full_text_parts = []

    for key, text in CASUAL_SCRIPTS.items():
        out_file = os.path.join(docs_audio_dir, f"{key}.mp3")
        print(f"Generating {key}.mp3 with {voice}...")
        communicate = edge_tts.Communicate(text, voice, rate=rate)
        await communicate.save(out_file)
        shutil.copy2(out_file, os.path.join(web_audio_dir, f"{key}.mp3"))
        full_text_parts.append(text)

    # Master full pitch track
    full_text = "\n\n ... \n\n".join(full_text_parts)
    full_out = os.path.join(docs_audio_dir, "glycolens_full_pitch.mp3")
    print("Generating full pitch master track...")
    comm_full = edge_tts.Communicate(full_text, voice, rate=rate)
    await comm_full.save(full_out)
    shutil.copy2(full_out, os.path.join(web_audio_dir, "glycolens_full_pitch.mp3"))

    # Also generate a backup with en-US-GuyNeural (laid-back, chill, friendly casual guy)
    guy_out = os.path.join(docs_audio_dir, "glycolens_casual_guy_alternate.mp3")
    print("Generating alternate chill version with en-US-GuyNeural...")
    comm_guy = edge_tts.Communicate(full_text, "en-US-GuyNeural", rate="+0%")
    await comm_guy.save(guy_out)
    shutil.copy2(guy_out, os.path.join(web_audio_dir, "glycolens_casual_guy_alternate.mp3"))

    print("\nSUCCESS: Casual cool voiceover generated for all slides and full tracks!")

if __name__ == "__main__":
    asyncio.run(generate_cool_voiceovers())
