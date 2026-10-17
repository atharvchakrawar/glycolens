import asyncio
import os
import shutil
import edge_tts

VOICE = "en-IN-PrabhatNeural"
RATE = "-3%"
PITCH = "+0Hz"

SCRIPTS = {
    "slide1_cover": (
        "Hello everyone! We are Team Binary Duo, and today we are excited to present GlycoLens: "
        "an AI-powered hypoglycemia early-warning and cultural Indian meal carb estimator. "
        "We are shifting diabetes management from reactive panic to proactive prevention, "
        "measured in how Indian families actually eat—in rotis and katoris."
    ),
    "slide2_problem": (
        "Let's look at the problem. In India alone, over 850,000 people live with Type 1 Diabetes, "
        "taking multiple daily insulin injections to survive. They face two massive struggles every single day. "
        "First: Existing Continuous Glucose Monitors only trigger alarms AFTER blood sugar drops below 70 mg/dL. "
        "By that point, the patient is already trembling, sweating, and cognitively impaired. "
        "Second: Western nutrition apps like MyFitnessPal demand raw gram weights—asking for 120 grams of boiled lentils. "
        "Nobody weighs food with a kitchen scale at an Indian family dinner! "
        "This leads to dosage guessing, frequent crashes, and over 30% of preventable emergency hospitalizations."
    ),
    "slide3_solution": (
        "GlycoLens solves both challenges with two core technological pillars. "
        "Pillar 1 is our Proactive PyTorch LSTM neural network. Instead of waiting for a crash, "
        "it evaluates real-time glucose rate-of-change velocity and active insulin to forecast where glucose will be "
        "30 and 60 minutes into the future. "
        "Pillar 2 is our Cultural Nutrition Engine, scientifically mapped to the ICMR National Institute of Nutrition "
        "Indian Food Composition Tables. It allows patients to log meals in real-world household portions—rotis and standard 9-centimeter katoris—calculating "
        "net carbs, dietary fiber, and glycemic load instantly."
    ),
    "slide4_features": (
        "Here are our key clinical features: "
        "First, our Velocity-Aware Glucose Gauge displays dynamic rate of change with a 90% confidence interval cone, "
        "accounting for biological variability. "
        "Second, our clinical Rule of 15 rescue protocol: when blood sugar drops, the app guides the patient to take "
        "15 grams of fast carbs and starts a 15-minute countdown timer to prevent dangerous rebound hyperglycemia. "
        "Third, dual-mode Indian food logging with both one-tap household builders and camera AI recognition. "
        "And crucially, GlycoLens operates strictly as Non-Device Clinical Decision Support, adhering to CDSCO and FDA guidelines."
    ),
    "slide5_livedemo": (
        "Now, let's look at the working prototype running live on my phone. "
        "On the dashboard, the live dial shows 110 mg/dL in the healthy green zone, with plus 30 and plus 60-minute forecast cards. "
        "When we simulate a sudden drop using the Post-Meal Low trigger, in under 15 milliseconds the PyTorch model detects the downward velocity. "
        "Instantly, the phone vibrates and a real lockscreen system notification appears: "
        "'Hypo Warning: Predicted in 38 minutes. Glucose dropping to 58 mg/dL. Eat a fruit or 15 grams of carbs now!' "
        "Next, when logging lunch, I simply select 2 Rotis, 1 Katori Dal, and 1 Katori Rice. "
        "The system calculates 59.7 grams of net carbs and updates our forecast trajectory. "
        "Everything is saved into the history timeline, and the Rule of 15 timer keeps the patient completely safe."
    ),
    "slide6_architecture": (
        "Behind the scenes, GlycoLens is built on an enterprise-grade, high-performance architecture: "
        "The client layer is a Flutter Progressive Web App with a custom Network-First service worker and W3C Web Notification API. "
        "The backend is powered by Python FastAPI and SQLite, delivering end-to-end inference and logging latencies under 15 milliseconds. "
        "Our PyTorch LSTM forecaster achieves an outstanding root-mean-square error of just 12.5 mg/dL. "
        "And our nutritional engine integrates fine-tuned YOLOv8 plate recognition calibrated against a standard 9-centimeter steel katori."
    ),
    "slide7_impact": (
        "Let's discuss clinical impact and feasibility: "
        "By providing a 30 to 60-minute early warning window, GlycoLens gives patients time to eat before cognitive impairment sets in. "
        "This prevents severe hypoglycemia, saving families between 15,000 to 50,000 rupees per avoided emergency room visit. "
        "Replacing gram scales with rotis and katoris increases long-term logging adherence from under 20% to over 85%. "
        "Our future roadmap includes direct Bluetooth Low Energy sensor pairing with Dexcom and FreeStyle Libre, "
        "vernacular voice logging in Hindi, Tamil, Telugu, and Marathi, and automated WhatsApp alert telemetry to reassure parents."
    ),
    "slide8_conclusion": (
        "To summarize: Diabetes management should not require carrying a kitchen scale, "
        "and it should never leave patients living in fear of a sudden low while driving or sleeping. "
        "GlycoLens combines proactive AI early warnings with culturally calibrated nutrition, right in your pocket. "
        "Sub-15 millisecond latency, native phone notifications, and ICMR scientific accuracy. "
        "Thank you so much! We are Team Binary Duo, and we are ready for your questions."
    ),
}

async def generate_all():
    docs_audio_dir = "docs/audio"
    web_audio_dir = "mobile/build/web/audio"
    os.makedirs(docs_audio_dir, exist_ok=True)
    os.makedirs(web_audio_dir, exist_ok=True)

    print("--- Synthesizing Section Audio Clips ---")
    full_text_parts = []

    for key, text in SCRIPTS.items():
        output_file = os.path.join(docs_audio_dir, f"{key}.mp3")
        print(f"Generating {key}.mp3...")
        communicate = edge_tts.Communicate(text, VOICE, rate=RATE, pitch=PITCH)
        await communicate.save(output_file)
        
        # Copy to web audio dir so the PWA / presentation can access it
        shutil.copy2(output_file, os.path.join(web_audio_dir, f"{key}.mp3"))
        full_text_parts.append(text)

    print("--- Synthesizing Full Continuous Pitch Track ---")
    full_text = "\n\n ... \n\n".join(full_text_parts)
    full_output = os.path.join(docs_audio_dir, "glycolens_full_pitch.mp3")
    communicate_full = edge_tts.Communicate(full_text, VOICE, rate=RATE, pitch=PITCH)
    await communicate_full.save(full_output)
    shutil.copy2(full_output, os.path.join(web_audio_dir, "glycolens_full_pitch.mp3"))

    print("\n✅ All voiceover files generated successfully!")
    print(f"Full Pitch Audio: {full_output}")
    print(f"Web Accessible Audio: {web_audio_dir}/glycolens_full_pitch.mp3")

if __name__ == "__main__":
    asyncio.run(generate_all())
