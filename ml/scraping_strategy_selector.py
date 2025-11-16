#!/usr/bin/env python3
"""
Free ML-Based Scraping Strategy Selector
Uses 100% free and open-source models:
- Ollama (local LLM deployment)
- Hugging Face Inference API (free tier)
- scikit-learn (local ML classification)
"""

import os
import json
import asyncio
from typing import Dict, List, Optional
import aiohttp
from loguru import logger
import numpy as np
from sklearn.ensemble import GradientBoostingClassifier
import joblib


class FreeMLScrapingSelector:
    """
    AI-Powered scraping method selector using 100% free models.
    
    Features:
    - Ollama local LLM for strategy reasoning
    - Hugging Face API for anti-bot detection
    - scikit-learn for method classification
    """

    def __init__(self):
        self.ollama_url = os.getenv('OLLAMA_URL', 'http://localhost:11434')
        self.hf_token = os.getenv('HUGGINGFACE_TOKEN', '')
        self.model_path = 'models/scraping_classifier.pkl'
        self.classifier = self._load_or_train_classifier()

    def _load_or_train_classifier(self):
        """Load pre-trained model or train new one."""
        try:
            return joblib.load(self.model_path)
        except FileNotFoundError:
            logger.warning("No pre-trained model found. Training new classifier...")
            return self._train_classifier()

    def _train_classifier(self):
        """Train Gradient Boosting classifier on synthetic data."""
        # Synthetic training data (replace with real data in production)
        X_train = np.random.rand(1000, 15)  # 15 features
        y_train = np.random.choice(['http', 'playwright', 'stealth', 'tor', 'proxy'], 1000)
        
        clf = GradientBoostingClassifier(
            n_estimators=100,
            max_depth=5,
            learning_rate=0.1,
            random_state=42
        )
        clf.fit(X_train, y_train)
        
        os.makedirs('models', exist_ok=True)
        joblib.dump(clf, self.model_path)
        logger.info("Classifier trained and saved")
        return clf

    async def analyze_with_ollama(self, url: str, html: str = None) -> Dict:
        """
        Use Ollama local LLM to analyze URL and recommend strategy.
        
        Free Models:
        - llama3:8b (Meta, Llama Community License)
        - mistral:7b (Apache 2.0)
        - qwen2.5:7b (Apache 2.0)
        - phi-4:14b (MIT License)
        """
        prompt = f"""
Analyze this URL for web scraping and recommend the best method.

URL: {url}
HTML Preview: {html[:500] if html else 'Not provided'}

Available methods:
1. HTTP - Simple requests for static sites
2. Playwright - For JavaScript-heavy sites
3. Puppeteer Stealth - For anti-bot protected sites
4. TOR Network - For geo-blocked content
5. Free Proxies - For rate-limited domains

Provide JSON response with:
{{
  "recommended_method": "method_name",
  "confidence": 0.0-1.0,
  "reasoning": "explanation",
  "anti_bot_detected": ["list of protections"],
  "bypass_strategies": ["list of strategies"]
}}
"""

        async with aiohttp.ClientSession() as session:
            try:
                async with session.post(
                    f"{self.ollama_url}/api/generate",
                    json={
                        "model": "llama3:8b",  # Free, high-quality
                        "prompt": prompt,
                        "stream": False,
                        "format": "json"
                    },
                    timeout=aiohttp.ClientTimeout(total=30)
                ) as response:
                    if response.status == 200:
                        data = await response.json()
                        return json.loads(data['response'])
                    else:
                        logger.error(f"Ollama API error: {response.status}")
                        return self._fallback_analysis(url)
            except Exception as e:
                logger.error(f"Ollama request failed: {e}")
                return self._fallback_analysis(url)

    async def detect_anti_bot_with_hf(self, html: str) -> Dict:
        """
        Use Hugging Face free Inference API for anti-bot detection.
        
        Free Models:
        - distilbert-base-uncased (text classification)
        - microsoft/resnet-50 (image analysis for CAPTCHA)
        """
        if not self.hf_token:
            logger.warning("No HF token, using rule-based detection")
            return self._rule_based_detection(html)

        API_URL = "https://api-inference.huggingface.co/models/distilbert-base-uncased"
        headers = {"Authorization": f"Bearer {self.hf_token}"}
        
        # Extract text for classification
        text_sample = html[:512] if html else ""
        
        async with aiohttp.ClientSession() as session:
            try:
                async with session.post(
                    API_URL,
                    headers=headers,
                    json={"inputs": text_sample},
                    timeout=aiohttp.ClientTimeout(total=10)
                ) as response:
                    if response.status == 200:
                        result = await response.json()
                        return self._parse_hf_response(result)
                    else:
                        return self._rule_based_detection(html)
            except Exception as e:
                logger.error(f"HF API failed: {e}")
                return self._rule_based_detection(html)

    def _rule_based_detection(self, html: str) -> Dict:
        """Fallback rule-based anti-bot detection."""
        if not html:
            return {"protections": [], "confidence": 0.5}
        
        html_lower = html.lower()
        protections = []
        
        if 'cloudflare' in html_lower or 'cf-ray' in html_lower:
            protections.append('cloudflare')
        if 'datadome' in html_lower:
            protections.append('datadome')
        if 'recaptcha' in html_lower:
            protections.append('recaptcha')
        if 'hcaptcha' in html_lower:
            protections.append('hcaptcha')
        if 'perimetrx' in html_lower or 'px-captcha' in html_lower:
            protections.append('perimeterx')
        
        return {
            "protections": protections,
            "confidence": 0.8 if protections else 0.9
        }

    def _parse_hf_response(self, result: List) -> Dict:
        """Parse Hugging Face classification response."""
        # HF returns list of labels with scores
        return {
            "protections": [item['label'] for item in result if item['score'] > 0.5],
            "confidence": max([item['score'] for item in result], default=0.5)
        }

    def extract_features(self, url: str, anti_bot: Dict) -> np.ndarray:
        """Extract features for sklearn classifier."""
        features = [
            len(url),  # URL length
            1 if 'https' in url else 0,  # SSL
            len(anti_bot.get('protections', [])),  # Protection count
            1 if 'cloudflare' in anti_bot.get('protections', []) else 0,
            1 if 'recaptcha' in anti_bot.get('protections', []) else 0,
            # ... add 10 more features
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0  # Placeholder features
        ]
        return np.array(features).reshape(1, -1)

    async def predict_method(self, url: str, html: str = None) -> Dict:
        """
        Main prediction function combining all free models.
        
        Returns:
            {
                "recommended_method": str,
                "confidence": float,
                "reasoning": str,
                "anti_bot_detected": List[str],
                "bypass_strategies": List[str],
                "fallback_methods": List[str]
            }
        """
        # 1. Detect anti-bot protections (HF or rule-based)
        anti_bot = await self.detect_anti_bot_with_hf(html) if html else {"protections": []}
        
        # 2. Get LLM reasoning (Ollama)
        llm_analysis = await self.analyze_with_ollama(url, html)
        
        # 3. Get ML classification (scikit-learn)
        features = self.extract_features(url, anti_bot)
        ml_method = self.classifier.predict(features)[0]
        ml_confidence = self.classifier.predict_proba(features).max()
        
        # 4. Combine all predictions
        if llm_analysis.get('confidence', 0) > 0.7:
            final_method = llm_analysis['recommended_method']
            confidence = llm_analysis['confidence']
        else:
            final_method = ml_method
            confidence = ml_confidence
        
        return {
            "recommended_method": final_method,
            "confidence": float(confidence),
            "reasoning": llm_analysis.get('reasoning', 'ML-based classification'),
            "anti_bot_detected": anti_bot.get('protections', []),
            "bypass_strategies": llm_analysis.get('bypass_strategies', []),
            "fallback_methods": self._get_fallback_cascade(final_method),
            "model_sources": {
                "llm": "Ollama (llama3:8b)",
                "anti_bot": "Hugging Face (distilbert) or rule-based",
                "classifier": "scikit-learn (Gradient Boosting)"
            }
        }

    def _get_fallback_cascade(self, primary_method: str) -> List[str]:
        """Get fallback methods in order of preference."""
        cascades = {
            'http': ['playwright', 'stealth'],
            'playwright': ['stealth', 'tor'],
            'stealth': ['tor', 'proxy'],
            'tor': ['proxy', 'stealth'],
            'proxy': ['tor', 'stealth']
        }
        return cascades.get(primary_method, ['stealth', 'tor'])

    def _fallback_analysis(self, url: str) -> Dict:
        """Fallback when Ollama is unavailable."""
        return {
            "recommended_method": "stealth",
            "confidence": 0.6,
            "reasoning": "Fallback to stealth (Ollama unavailable)",
            "anti_bot_detected": [],
            "bypass_strategies": ["rotate_user_agent", "enable_stealth"]
        }


# FastAPI endpoint integration
if __name__ == "__main__":
    from fastapi import FastAPI, HTTPException
    from pydantic import BaseModel
    
    app = FastAPI(title="Free ML Scraping Strategy Selector")
    selector = FreeMLScrapingSelector()
    
    class ScrapingRequest(BaseModel):
        url: str
        html: Optional[str] = None
    
    @app.post("/api/v1/predict-method")
    async def predict(request: ScrapingRequest):
        try:
            result = await selector.predict_method(request.url, request.html)
            return result
        except Exception as e:
            logger.error(f"Prediction failed: {e}")
            raise HTTPException(status_code=500, detail=str(e))
    
    @app.get("/health")
    async def health():
        return {"status": "ok", "models": "ollama + huggingface + sklearn"}
    
    # Run: uvicorn scraping_strategy_selector:app --host 0.0.0.0 --port 8000
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
