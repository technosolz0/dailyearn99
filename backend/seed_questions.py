import os
import sys
import json
import random
from datetime import datetime, timezone

# Add the parent directory to the path so we can import from app
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.core.database import SessionLocal
from app.models import Question

BASE_QUESTIONS = {
    "en": [
        {
            "text": "Which country won the ICC Men's T20 World Cup in 2024?",
            "options": ["India", "South Africa", "Australia", "England"],
            "correct_answer_index": 0
        },
        {
            "text": "In computer networking, what does VPN stand for?",
            "options": ["Virtual Private Network", "Vector Protocol Node", "Valued Personal Network", "Virtual Packet Node"],
            "correct_answer_index": 0
        },
        {
            "text": "Which programming language is predominantly used to write Flutter apps?",
            "options": ["Swift", "Dart", "Kotlin", "Rust"],
            "correct_answer_index": 1
        },
        {
            "text": "What is the national game of India officially/historically?",
            "options": ["Cricket", "Kabaddi", "Field Hockey", "Football"],
            "correct_answer_index": 2
        },
        {
            "text": "What is the platform fee target percentage in target99?",
            "options": ["10-20%", "15-35%", "50-60%", "5%"],
            "correct_answer_index": 1
        },
        {
            "text": "Which chemical element has the symbol Au?",
            "options": ["Silver", "Copper", "Gold", "Iron"],
            "correct_answer_index": 2
        },
        {
            "text": "Which planet in our solar system is known for its prominent rings?",
            "options": ["Mars", "Jupiter", "Saturn", "Neptune"],
            "correct_answer_index": 2
        },
        {
            "text": "Who painted the famous Mona Lisa?",
            "options": ["Vincent van Gogh", "Leonardo da Vinci", "Pablo Picasso", "Michelangelo"],
            "correct_answer_index": 1
        },
        {
            "text": "Which is the largest ocean on Earth?",
            "options": ["Atlantic Ocean", "Indian Ocean", "Southern Ocean", "Pacific Ocean"],
            "correct_answer_index": 3
        },
        {
            "text": "Which country is the largest by land area?",
            "options": ["Canada", "China", "Russia", "United States"],
            "correct_answer_index": 2
        },
        {
            "text": "What is the capital city of Australia?",
            "options": ["Sydney", "Melbourne", "Canberra", "Brisbane"],
            "correct_answer_index": 2
        },
        {
            "text": "Who is the author of \"Harry Potter\"?",
            "options": ["J.R.R. Tolkien", "J.K. Rowling", "George R.R. Martin", "C.S. Lewis"],
            "correct_answer_index": 1
        }
    ],
    "hi": [
        {
            "text": "किस देश ने 2024 में आईसीसी पुरुष टी20 विश्व कप जीता?",
            "options": ["भारत", "दक्षिण अफ्रीका", "ऑस्ट्रेलिया", "इंग्लैंड"],
            "correct_answer_index": 0
        },
        {
            "text": "कंप्यूटर नेटवर्किंग में, VPN का क्या अर्थ है?",
            "options": ["वर्चुअल प्राइवेट नेटवर्क", "वेक्टर प्रोटोकॉल नोड", "वैल्यूड पर्सनल नेटवर्क", "वर्चुअल पैकेट नोड"],
            "correct_answer_index": 0
        },
        {
            "text": "फ्लटर ऐप लिखने के लिए मुख्य रूप से किस प्रोग्रामिंग भाषा का उपयोग किया जाता है?",
            "options": ["स्विफ्ट", "डार्ट", "कोटलिन", "रस्ट"],
            "correct_answer_index": 1
        },
        {
            "text": "आधिकारिक/ऐतिहासिक रूप से भारत का राष्ट्रीय खेल क्या है?",
            "options": ["क्रिकेट", "कबड्डी", "फील्ड हॉकी", "फुटबॉल"],
            "correct_answer_index": 2
        },
        {
            "text": "target99 में प्लेटफॉर्म शुल्क का लक्ष्य प्रतिशत क्या है?",
            "options": ["10-20%", "15-35%", "50-60%", "5%"],
            "correct_answer_index": 1
        },
        {
            "text": "किस रासायनिक तत्व का प्रतीक Au है?",
            "options": ["चांदी", "तांबा", "सोना", "लोहा"],
            "correct_answer_index": 2
        },
        {
            "text": "हमारे सौरमंडल का कौन सा ग्रह अपने प्रमुख छल्लों के लिए जाना जाता है?",
            "options": ["मंगल", "बृहस्पति", "शनि", "वरुण"],
            "correct_answer_index": 2
        },
        {
            "text": "प्रसिद्ध मोनालिसा की पेंटिंग किसने बनाई थी?",
            "options": ["विन्सेंट वैन गॉग", "लियोनार्डो दा विंची", "पाब्लो पिकासो", "माइकल एंजेलो"],
            "correct_answer_index": 1
        },
        {
            "text": "पृथ्वी पर सबसे बड़ा महासागर कौन सा है?",
            "options": ["अटलांटिक महासागर", "हिंद महासागर", "दक्षिणी महासागर", "प्रशांत महासागर"],
            "correct_answer_index": 3
        },
        {
            "text": "भूमि क्षेत्र के हिसाब से सबसे बड़ा देश कौन सा है?",
            "options": ["कनाडा", "चीन", "रूस", "संयुक्त राज्य अमेरिका"],
            "correct_answer_index": 2
        },
        {
            "text": "ऑस्ट्रेलिया की राजधानी कौन सी है?",
            "options": ["सिडनी", "मेलबर्न", "कैनबरा", "ब्रिस्बेन"],
            "correct_answer_index": 2
        },
        {
            "text": "\"हैरी पॉटर\" के लेखक कौन हैं?",
            "options": ["जे.आर.आर. टोल्किन", "जे.के. रोलिंग", "जॉर्ज आर.आर. मार्टिन", "सी.एस. लुईस"],
            "correct_answer_index": 1
        }
    ],
    "mr": [
        {
            "text": "२०२४ मध्ये कोणत्या देशाने आयसीसी पुरुषांचा टी-२० विश्वचषक जिंकला?",
            "options": ["भारत", "दक्षिण आफ्रिका", "ऑस्ट्रेलिया", "इंग्लंड"],
            "correct_answer_index": 0
        },
        {
            "text": "संगणक नेटवर्किंगमध्ये, VPN म्हणजे काय?",
            "options": ["व्हर्च्युअल प्रायव्हेट नेटवर्क", "वेक्टर प्रोटोकॉल नोड", "व्हॅल्यूड पर्सनल नेटवर्क", "व्हर्च्युअल पॅकेट नोड"],
            "correct_answer_index": 0
        },
        {
            "text": "फ्लटर ॲप्स लिहिण्यासाठी प्रामुख्याने कोणती प्रोग्रामिंग भाषा वापरली जाते?",
            "options": ["स्विफ्ट", "डार्ट", "कोटलीन", "रस्ट"],
            "correct_answer_index": 1
        },
        {
            "text": "अधिकृतपणे/ऐतिहासिकदृष्ट्या भारताचा राष्ट्रीय खेळ कोणता आहे?",
            "options": ["क्रिकेट", "कबड्डी", "फील्ड हॉकी", "फुटबॉल"],
            "correct_answer_index": 2
        },
        {
            "text": "target99 मध्ये प्लॅटफॉर्म फीचे लक्ष्य टक्केवारी काय आहे?",
            "options": ["10-20%", "15-35%", "50-60%", "5%"],
            "correct_answer_index": 1
        },
        {
            "text": "कोणत्या रासायनिक घटकाचे चिन्ह Au आहे?",
            "options": ["चांदी", "तांबे", "सोने", "लोखंड"],
            "correct_answer_index": 2
        },
        {
            "text": "आपल्या सूर्यमालेतील कोणता ग्रह त्याच्या ठळक कड्यांसाठी ओळखला जातो?",
            "options": ["मंगळ", "गुरु", "शनी", "नेपच्यून"],
            "correct_answer_index": 2
        },
        {
            "text": "प्रसिद्ध मोनालिसाचे चित्र कोणी काढले?",
            "options": ["विन्सेंट व्हॅन गॉग", "लिओनार्डो दा विंची", "पाब्लो पिकासो", "मायकेलएंजेलो"],
            "correct_answer_index": 1
        },
        {
            "text": "पृथ्वीवरील सर्वात मोठा महासागर कोणता आहे?",
            "options": ["अटलांटिक महासागर", "हिंदी महासागर", "दक्षिण महासागर", "प्रशांत महासागर"],
            "correct_answer_index": 3
        },
        {
            "text": "जमिनीच्या क्षेत्रफळानुसार सर्वात मोठा देश कोणता आहे?",
            "options": ["कॅनडा", "चीन", "रशिया", "अमेरिका"],
            "correct_answer_index": 2
        },
        {
            "text": "ऑस्ट्रेलियाची राजधानी कोणती आहे?",
            "options": ["सिडनी", "मेलबर्न", "कॅनबेरा", "ब्रिस्बेन"],
            "correct_answer_index": 2
        },
        {
            "text": "\"हॅरी पॉटर\" चे लेखक कोण आहेत?",
            "options": ["जे.आर.आर. टॉल्किन", "जे.के. रोलिंग", "जॉर्ज आर.आर. मार्टिन", "सी.एस. लुईस"],
            "correct_answer_index": 1
        }
    ],
    "gu": [
        {
            "text": "કયા દેશે 2024 માં આઇસીસી મેન્સ ટી20 વર્લ્ડ કપ જીત્યો?",
            "options": ["ભારત", "દક્ષિણ આફ્રિકા", "ઓસ્ટ્રેલિયા", "ઇંગ્લેન્ડ"],
            "correct_answer_index": 0
        },
        {
            "text": "કમ્પ્યુટર નેટવર્કિંગમાં, VPN નું પૂરું નામ શું છે?",
            "options": ["વર્ચ્યુઅલ પ્રાઇવેટ નેટવર્ક", "વેક્ટર પ્રોટોકોલ નોડ", "વેલ્યૂડ પર્સનલ નેટવર્ક", "વર્ચ્યુઅલ પેકેટ નોડ"],
            "correct_answer_index": 0
        },
        {
            "text": "ફ્લટર એપ્લિકેશન લખવા માટે મુખ્યત્વે કઈ પ્રોગ્રામિંગ ભાષાનો ઉપયોગ થાય છે?",
            "options": ["સ્વિફ્ટ", "ડાર્ટ", "કોટલિન", "રસ્ટ"],
            "correct_answer_index": 1
        },
        {
            "text": "સત્તાવાર/ઐતિહાસિક રીતે ભારતની રાષ્ટ્રીય રમત કઈ છે?",
            "options": ["ક્રિકેટ", "કબડ્ડી", "ફીલ્ડ હોકી", "ફૂટબોલ"],
            "correct_answer_index": 2
        },
        {
            "text": "target99 માં પ્લેટફોર્મ ફીની લક્ષ્ય ટકાવારી શું છે?",
            "options": ["10-20%", "15-35%", "50-60%", "5%"],
            "correct_answer_index": 1
        },
        {
            "text": "કયા રાસાયણિક તત્વની સંજ્ઞા Au છે?",
            "options": ["ચાંદી", "તાંબુ", "સોનું", "લોખંડ"],
            "correct_answer_index": 2
        },
        {
            "text": "આપણા સૂર્યમંડળનો કયો ગ્રહ તેના વલયો માટે જાણીતો છે?",
            "options": ["મંગળ", "ગુરુ", "શનિ", "નેપ્ચ્યુન"],
            "correct_answer_index": 2
        },
        {
            "text": "પ્રખ્યાત મોના લિસાનું ચિત્ર કોણે દોર્યું હતું?",
            "options": ["વિન્સેન્ટ વેન ગોગ", "લિયોનાર્ડો દા વિંચી", "પાબ્લો પિકાસો", "માઈકલ એન્જેલો"],
            "correct_answer_index": 1
        },
        {
            "text": "પૃથ્વી પરનો સૌથી મોટો મહાસાગર કયો છે?",
            "options": ["એટલાન્ટિક મહાસાગર", "હિંદ મહાસાગર", "દક્ષિણ મહાસાગર", "પ્રશાંત મહાસાગર"],
            "correct_answer_index": 3
        },
        {
            "text": "જમીન વિસ્તારની દ્રષ્ટિએ સૌથી મોટો દેશ કયો છે?",
            "options": ["કેનેડા", "ચીન", "રશિયા", "યુનાઇટેડ સ્ટેટ્સ"],
            "correct_answer_index": 2
        },
        {
            "text": "ઓસ્ટ્રેલિયાનું પાટનગર કયું છે?",
            "options": ["સિડની", "મેલબોોર્ન", "કેનબેરા", "બ્રિસ્બેન"],
            "correct_answer_index": 2
        },
        {
            "text": "\"હેરી પોટર\" ના લેખક કોણ છે?",
            "options": ["જે.આર.આર. ટોલ્કિન", "જે.કે. રોલિંગ", "જ્યોર્જ આર.આર. માર્ટિન", "સી.એસ. લેવિસ"],
            "correct_answer_index": 1
        }
    ]
}

MATH_TEMPLATES = {
    "en": {
        "addition": "What is the sum of {a} and {b}?",
        "subtraction": "What is the result when {a} is subtracted from {b}?",
        "multiplication": "What is the product of {a} and {b}?",
        "division": "What is {a} divided by {b}?",
        "linear_add": "If {a}x + {b} = {c}, what is the value of x?",
        "prime": "Which of the following numbers is a prime number?",
        "percentage": "What is {p}% of {v}?",
        "area_rect": "What is the area of a rectangle with length {l} cm and width {w} cm?",
        "area_tri": "What is the area of a right-angled triangle with base {b} cm and height {h} cm?",
        "linear_div": "If {a}x = {b}, what is the value of x?",
        "sqrt": "What is the square root of {square}?",
        "exponent": "What is the value of {a} raised to the power of {b}?",
        "area_sq": "What is the area of a square with side length {side} cm?",
        "perimeter_sq": "What is the perimeter of a square with side length {side} cm?",
        "gcd": "What is the Greatest Common Divisor (GCD) of {a} and {b}?",
        "lcm": "What is the Least Common Multiple (LCM) of {a} and {b}?"
    },
    "hi": {
        "addition": "{a} और {b} का योग क्या है?",
        "subtraction": "जब {b} में से {a} घटाया जाता है, तो क्या परिणाम होता है?",
        "multiplication": "{a} और {b} का गुणनफल क्या है?",
        "division": "{a} को {b} से विभाजित करने पर क्या होगा?",
        "linear_add": "यदि {a}x + {b} = {c} है, तो x का मान क्या है?",
        "prime": "निम्नलिखित में से कौन सी संख्या एक अभाज्य संख्या है?",
        "percentage": "{v} का {p}% क्या है?",
        "area_rect": "{l} सेमी लंबाई और {w} सेमी चौड़ाई वाले आयत का क्षेत्रफल क्या है?",
        "area_tri": "आधार {b} सेमी और ऊंचाई {h} सेमी वाले समकोण त्रिभुज का क्षेत्रफल क्या है?",
        "linear_div": "यदि {a}x = {b} है, तो x का मान क्या है?",
        "sqrt": "{square} का वर्गमूल क्या है?",
        "exponent": "{a} की घात {b} का मान क्या है?",
        "area_sq": "{side} सेमी भुजा वाले वर्ग का क्षेत्रफल क्या है?",
        "perimeter_sq": "{side} सेमी भुजा वाले वर्ग का परिमाप क्या है?",
        "gcd": "{a} और {b} का महत्तम समापवर्तक (GCD) क्या है?",
        "lcm": "{a} और {b} का लघुत्तम समापवर्त्य (LCM) क्या है?"
    },
    "mr": {
        "addition": "{a} आणि {b} ची बेरीज काय आहे?",
        "subtraction": "जेव्हा {b} मधून {a} वजा केले जाते, तेव्हा काय उत्तर येते?",
        "multiplication": "{a} आणि {b} चा गुणाकार काय आहे?",
        "division": "{a} ला {b} ने भागल्यास काय येईल?",
        "linear_add": "जर {a}x + {b} = {c}, तर x ची किंमत काय आहे?",
        "prime": "खालीलपैकी कोणती संख्या मूळ संख्या आहे?",
        "percentage": "{v} चे {p}% काय आहे?",
        "area_rect": "लांबी {l} सेमी आणि रुंदी {w} सेमी असलेल्या आयताचे क्षेत्रफळ काय आहे?",
        "area_tri": "पाया {b} सेमी आणि उंची {h} सेमी असलेल्या काटकोन त्रिकोणाचे क्षेत्रफळ काय आहे?",
        "linear_div": "जर {a}x = {b}, तर x ची किंमत काय आहे?",
        "sqrt": "{square} चे वर्गमूळ काय आहे?",
        "exponent": "{a} चा घातांक {b} ची किंमत काय आहे?",
        "area_sq": "बाजूची लांबी {side} सेमी असलेल्या चौरसाचे क्षेत्रफळ काय आहे?",
        "perimeter_sq": "बाजूची लांबी {side} सेमी असलेल्या चौरसाची परिमिती काय आहे?",
        "gcd": "{a} आणि {b} चा महत्तम सामायिक विभाजक (GCD) काय आहे?",
        "lcm": "{a} आणि {b} चा लघूत्तम सामायिक विभाज्य (LCM) काय आहे?"
    },
    "gu": {
        "addition": "{a} અને {b} નો સરવાળો કેટલો થાય?",
        "subtraction": "જ્યારે {b} માંથી {a} બાદ કરવામાં આવે, ત્યારે શું પરિણામ મળે?",
        "multiplication": "{a} અને {b} નો ગુણાકાર કેટલો થાય?",
        "division": "{a} ને {b} વડે ભાગતા શું મળશે?",
        "linear_add": "જો {a}x + {b} = {c} હોય, તો x ની કિંમત શું છે?",
        "prime": "નીચેનામાંથી કઈ સંખ્યા અવિભાજ્ય સંખ્યા છે?",
        "percentage": "{v} ના {p}% કેટલા થાય?",
        "area_rect": "{l} સેમી લંબાઈ અને {w} સેમી પહોળાઈ ધરાવતા લંબચોરસનું ક્ષેત્રફળ કેટલું થાય?",
        "area_tri": "પાયો {b} સેમી અને ઊંચાઈ {h} સેમી ધરાવતા કાટકોણ ત્રિકોણનું ક્ષેત્રફળ કેટલું થાય?",
        "linear_div": "જો {a}x = {b} હોય, તો x ની કિંમત શું છે?",
        "sqrt": "{square} નું વર્ગમૂળ શું છે?",
        "exponent": "{a} ની {b} ઘાત ની કિંમત શું છે?",
        "area_sq": "{side} સેમી બાજુની લંબાઈ ધરાવતા ચોરસનું ક્ષેત્રફળ કેટલું થાય?",
        "perimeter_sq": "{side} સેમી બાજુની લંબાઈ ધરાવતા ચોરસની પરિમિતિ કેટલી થાય?",
        "gcd": "{a} અને {b} નો ગુરુત્તમ સામાન્ય અવયવ (GCD) શું છે?",
        "lcm": "{a} અને {b} નો લઘુત્તમ સામાન્ય ગુણક (LCM) શું છે?"
    }
}

GEO_TEMPLATES = {
    "en": {
        "capital": "What is the capital city of {country}?",
        "continent": "In which continent is the country of {country} located?",
        "currency": "What is the official currency of {country}?"
    },
    "hi": {
        "capital": "{country} की राजधानी कौन सी है?",
        "continent": "{country} किस महाद्वीप में स्थित है?",
        "currency": "{country} की आधिकारिक मुद्रा क्या है?"
    },
    "mr": {
        "capital": "{country} ची राजधानी कोणती आहे?",
        "continent": "{country} हा देश कोणत्या खंडात आहे?",
        "currency": "{country} चे अधिकृत चलन कोणते आहे?"
    },
    "gu": {
        "capital": "{country} નું પાટનગર કયું છે?",
        "continent": "{country} દેશ કયા ખંડમાં આવેલો છે?",
        "currency": "{country} નું સત્તાવાર ચલણ કયું છે?"
    }
}

PLANET_TEMPLATES = {
    "en": {
        "nickname": "Which planet in our solar system is known as the '{nickname}'?",
        "order": "Which planet is the {order} planet from the Sun in our solar system?"
    },
    "hi": {
        "nickname": "हमारे सौरमंडल के किस ग्रह को '{nickname}' के रूप में जाना जाता है?",
        "order": "हमारे सौरमंडल में सूर्य से {order} ग्रह कौन सा है?"
    },
    "mr": {
        "nickname": "आपल्या सूर्यमालेतील कोणता ग्रह '{nickname}' म्हणून ओळखला जातो?",
        "order": "आपल्या सूर्यमालेत सूर्यापासूनचा {order} ग्रह कोणता आहे?"
    },
    "gu": {
        "nickname": "આપણા સૂર્યમંડળના કયા ગ્રહને '{nickname}' તરીકે ઓળખવામાં આવે છે?",
        "order": "આપણા સૂર્યમંડળમાં સૂર્યથી {order} ગ્રહ કયો છે?"
    }
}

countries_data = [
    {
        "name": {"en": "Japan", "hi": "जापान", "mr": "जपान", "gu": "જાપાન"},
        "capital": {"en": "Tokyo", "hi": "टोक्यो", "mr": "टोक्यो", "gu": "ટોક્યો"},
        "continent": {"en": "Asia", "hi": "एशिया", "mr": "आशिया", "gu": "એશિયા"},
        "currency": {"en": "Yen", "hi": "येन", "mr": "येन", "gu": "યેન"}
    },
    {
        "name": {"en": "France", "hi": "फ्रांस", "mr": "फ्रान्स", "gu": "ફ્રાન્સ"},
        "capital": {"en": "Paris", "hi": "पेरिस", "mr": "पॅरिस", "gu": "પેરિસ"},
        "continent": {"en": "Europe", "hi": "यूरोप", "mr": "युरोप", "gu": "યુરોપ"},
        "currency": {"en": "Euro", "hi": "यूरो", "mr": "युरो", "gu": "યુરો"}
    },
    {
        "name": {"en": "Germany", "hi": "जर्मनी", "mr": "जर्मनी", "gu": "જર્મनी"},
        "capital": {"en": "Berlin", "hi": "बर्लिन", "mr": "बर्लिन", "gu": "બર્લિન"},
        "continent": {"en": "Europe", "hi": "यूरोप", "mr": "युरोप", "gu": "યુરોપ"},
        "currency": {"en": "Euro", "hi": "यूरो", "mr": "युरो", "gu": "યુરો"}
    },
    {
        "name": {"en": "Italy", "hi": "इटली", "mr": "इटली", "gu": "ઇતાલી"},
        "capital": {"en": "Rome", "hi": "रोम", "mr": "रोम", "gu": "રોમ"},
        "continent": {"en": "Europe", "hi": "यूरोप", "mr": "युरोप", "gu": "યુરોप"},
        "currency": {"en": "Euro", "hi": "यूरो", "mr": "युरो", "gu": "યુરો"}
    },
    {
        "name": {"en": "Canada", "hi": "कनाडा", "mr": "कॅनडा", "gu": "કેનેડા"},
        "capital": {"en": "Ottawa", "hi": "ओटावा", "mr": "ओटावा", "gu": "ઓટાવા"},
        "continent": {"en": "North America", "hi": "उत्तरी अमेरिका", "mr": "उत्तर अमेरिका", "gu": "ઉત્તર અમેરિકા"},
        "currency": {"en": "Canadian Dollar", "hi": "कनाडाई डॉलर", "mr": "कॅनेडियन डॉलर", "gu": "કેનેડિયન ડોલર"}
    },
    {
        "name": {"en": "Australia", "hi": "ऑस्ट्रेलिया", "mr": "ऑस्ट्रेलिया", "gu": "ઓસ્ટ્રેલિયા"},
        "capital": {"en": "Canberra", "hi": "कैनबरा", "mr": "कॅनबेरा", "gu": "કેનબેરા"},
        "continent": {"en": "Australia", "hi": "ऑस्ट्रेलिया", "mr": "ऑस्ट्रेलिया", "gu": "ઓસ્ટ્રેલિયા"},
        "currency": {"en": "Australian Dollar", "hi": "ऑस्ट्रेलियाई डॉलर", "mr": "ऑस्ट्रेलियन डॉलर", "gu": "ઓસ્ટ્રેલિયન ડોલર"}
    },
    {
        "name": {"en": "India", "hi": "भारत", "mr": "भारत", "gu": "ભારત"},
        "capital": {"en": "New Delhi", "hi": "नई दिल्ली", "mr": "नवी दिल्ली", "gu": "નવી દિલ્હી"},
        "continent": {"en": "Asia", "hi": "एशिया", "mr": "आशिया", "gu": "એશિયા"},
        "currency": {"en": "Rupee", "hi": "रुपया", "mr": "रुपया", "gu": "રૂપિયો"}
    },
    {
        "name": {"en": "China", "hi": "चीन", "mr": "चीन", "gu": "ચીન"},
        "capital": {"en": "Beijing", "hi": "बीजिंग", "mr": "बीजिंग", "gu": "બેઇજિંગ"},
        "continent": {"en": "Asia", "hi": "एशिया", "mr": "आशिया", "gu": "એશિયા"},
        "currency": {"en": "Yuan", "hi": "युआन", "mr": "युआन", "gu": "યુઆન"}
    },
    {
        "name": {"en": "Brazil", "hi": "ब्राजील", "mr": "ब्राझील", "gu": "બ્રાઝિલ"},
        "capital": {"en": "Brasilia", "hi": "ब्रासीलिया", "mr": "ब्राझीलिया", "gu": "બ્રાસિલિયા"},
        "continent": {"en": "South America", "hi": "दक्षिणी अमेरिका", "mr": "दक्षिण अमेरिका", "gu": "દક્ષિણ અમેરિકા"},
        "currency": {"en": "Real", "hi": "रियल", "mr": "रियाल", "gu": "રિયાલ"}
    },
    {
        "name": {"en": "South Africa", "hi": "दक्षिण अफ्रीका", "mr": "Ref", "gu": "દક્ષિણ આફ્રિકા"},
        "capital": {"en": "Pretoria", "hi": "प्रिटोरिया", "mr": "प्रिटोरिया", "gu": "પ્રિટોરિયા"},
        "continent": {"en": "Africa", "hi": "अफ्रीका", "mr": "आफ्रिका", "gu": "આફ્રિકા"},
        "currency": {"en": "Rand", "hi": "रैंड", "mr": "रँड", "gu": "રેન્ડ"}
    },
    {
        "name": {"en": "Russia", "hi": "रूस", "mr": "रशिया", "gu": "રશિયા"},
        "capital": {"en": "Moscow", "hi": "मॉस्को", "mr": "मॉस्को", "gu": "મોસ્કો"},
        "continent": {"en": "Europe", "hi": "यूरोप", "mr": "युरोप", "gu": "યુરોપ"},
        "currency": {"en": "Ruble", "hi": "रूबल", "mr": "रुबल", "gu": "રુબલ"}
    },
    {
        "name": {"en": "United Kingdom", "hi": "यूनाइटेड किंगडम", "mr": "युनायटेड किंगडम", "gu": "યુનાઇટેડ કિંગડમ"},
        "capital": {"en": "London", "hi": "लंदन", "mr": "लंडन", "gu": "لંડન"},
        "continent": {"en": "Europe", "hi": "यूरोप", "mr": "युरोप", "gu": "યુરોપ"},
        "currency": {"en": "Pound Sterling", "hi": "पाउंड स्टर्लिंग", "mr": "पाउंड स्टर्लिंग", "gu": "પાઉન્ડ સ્ટર્લિંગ"}
    },
    {
        "name": {"en": "Egypt", "hi": "मिस्र", "mr": "इजिप्त", "gu": "ઇજિપ્ત"},
        "capital": {"en": "Cairo", "hi": "काहिरा", "mr": "कैरो", "gu": "કૈરો"},
        "continent": {"en": "Africa", "hi": "अफ्रीका", "mr": "आफ्रिका", "gu": "આફ્રિકા"},
        "currency": {"en": "Egyptian Pound", "hi": "मिस्र का पाउंड", "mr": "इजिप्शियन पाउंड", "gu": "ઇજિપ્તિયન પાઉન્ડ"}
    },
    {
        "name": {"en": "Spain", "hi": "स्पेन", "mr": "स्पेन", "gu": "સ્પેન"},
        "capital": {"en": "Madrid", "hi": "मैड्रिड", "mr": "माद्रिद", "gu": "મેડ્રિડ"},
        "continent": {"en": "Europe", "hi": "यूरोप", "mr": "युरोप", "gu": "યુરોપ"},
        "currency": {"en": "Euro", "hi": "यूरो", "mr": "युरो", "gu": "યુરો"}
    }
]

planets_data = [
    {
        "name": {"en": "Mercury", "hi": "बुध", "mr": "बुध", "gu": "બુધ"},
        "nickname": {"en": "Swift Planet", "hi": "सबसे तेज ग्रह", "mr": "सर्वात वेगवान ग्रह", "gu": "સૌથી ઝડપી ગ્રહ"},
        "order": {"en": "first", "hi": "पहला", "mr": "पहिला", "gu": "પહેલો"}
    },
    {
        "name": {"en": "Venus", "hi": "शुक्र", "mr": "शुक्र", "gu": "શુક્ર"},
        "nickname": {"en": "Morning Star / Evening Star", "hi": "भोर का तारा / साझ का तारा", "mr": "पहाटेचा तारा / संध्याकाळचा तारा", "gu": "સવારનો તારો / સાંજનો તારો"},
        "order": {"en": "second", "hi": "दूसरा", "mr": "दुसरा", "gu": "બીજો"}
    },
    {
        "name": {"en": "Earth", "hi": "पृथ्वी", "mr": "पृथ्वी", "gu": "ਪૃથ્વી"},
        "nickname": {"en": "Blue Planet", "hi": "नीला ग्रह", "mr": "निळा ग्रह", "gu": "વાદળી ગ્રહ"},
        "order": {"en": "third", "hi": "तीसरा", "mr": "तिसरा", "gu": "ત્રીજો"}
    },
    {
        "name": {"en": "Mars", "hi": "मंगल", "mr": "मंगळ", "gu": "મંગળ"},
        "nickname": {"en": "Red Planet", "hi": "लाल ग्रह", "mr": "लाल ग्रह", "gu": "લાલ ગ્રહ"},
        "order": {"en": "fourth", "hi": "चौथा", "mr": "चौथा", "gu": "ચોથો"}
    },
    {
        "name": {"en": "Jupiter", "hi": "बृहस्पति", "mr": "गुरु", "gu": "ગુરુ"},
        "nickname": {"en": "Giant Planet", "hi": "विशाल ग्रह", "mr": "प्रचंड ग्रह", "gu": "વિશાળ ગ્રહ"},
        "order": {"en": "fifth", "hi": "पांचवां", "mr": "पाचवा", "gu": "પાંચમો"}
    },
    {
        "name": {"en": "Saturn", "hi": "शनि", "mr": "शनी", "gu": "શનિ"},
        "nickname": {"en": "Ringed Planet", "hi": "वलययुक्त ग्रह", "mr": "कड्यांचा ग्रह", "gu": "વલयवाળો ગ્રહ"},
        "order": {"en": "sixth", "hi": "छठा", "mr": "सहावा", "gu": "છઠ્ઠો"}
    },
    {
        "name": {"en": "Uranus", "hi": "अरुण (यूरेनस)", "mr": "युरेनस", "gu": "યુરેનસ"},
        "nickname": {"en": "Ice Giant", "hi": "बर्फ का दानव", "mr": "बर्फाचा राक्षस", "gu": "બરફનો જાયન્ટ"},
        "order": {"en": "seventh", "hi": "सातवां", "mr": "सातवा", "gu": "સાતમો"}
    },
    {
        "name": {"en": "Neptune", "hi": "वरुण (नेप्च्यून)", "mr": "नेपच्यून", "gu": "નેપ્ચ્યુન"},
        "nickname": {"en": "Windy Planet / Blue Giant", "hi": "हवादार ग्रह", "mr": "वादळी ग्रह", "gu": "પવનવાળો ગ્રહ"},
        "order": {"en": "eighth", "hi": "आठवां", "mr": "आठवा", "gu": "આઠમો"}
    }
]

def gcd(x, y):
    while y:
        x, y = y, x % y
    return x

def lcm(x, y):
    return (x * y) // gcd(x, y) if x or y else 0

def generate_questions_for_lang(lang):
    rng = random.Random(42)  # Stable, seeded RNG per language
    questions = []

    # 1. Base Questions
    if lang in BASE_QUESTIONS:
        for q_data in BASE_QUESTIONS[lang]:
            questions.append({
                "text": q_data["text"],
                "options": q_data["options"],
                "correct_answer_index": q_data["correct_answer_index"],
                "language": lang
            })

    def add_q(text, correct, distractors):
        clean_distractors = []
        for d in distractors:
            s_d = str(d)
            s_c = str(correct)
            if s_d != s_c and s_d not in clean_distractors:
                clean_distractors.append(s_d)
        
        while len(clean_distractors) < 3:
            clean_distractors.append(f"{len(clean_distractors) + 2}")
            
        options = [str(correct)] + clean_distractors[:3]
        rng.shuffle(options)
        correct_idx = options.index(str(correct))
        questions.append({
            "text": text,
            "options": options,
            "correct_answer_index": correct_idx,
            "language": lang
        })

    # ==================== CATEGORY: MATHS ====================
    templates = MATH_TEMPLATES[lang]

    # Addition (40 questions)
    for _ in range(40):
        a = rng.randint(10, 99)
        b = rng.randint(10, 99)
        ans = a + b
        distractors = [ans + 10, ans - 10, ans + rng.choice([-1, 1, -2, 2]) * 5]
        add_q(templates["addition"].format(a=a, b=b), ans, distractors)

    # Subtraction (40 questions)
    for _ in range(40):
        b = rng.randint(20, 99)
        a = rng.randint(10, b - 1)
        ans = b - a
        distractors = [ans + 5, ans - 5 if ans > 5 else ans + 15, ans + rng.choice([10, 20])]
        add_q(templates["subtraction"].format(a=a, b=b), ans, distractors)

    # Multiplication (40 questions)
    for _ in range(40):
        a = rng.randint(2, 12)
        b = rng.randint(2, 20)
        ans = a * b
        distractors = [ans + a, ans - b, ans + rng.choice([-1, 1]) * 10]
        add_q(templates["multiplication"].format(a=a, b=b), ans, distractors)

    # Division (30 questions)
    for _ in range(30):
        b = rng.randint(2, 10)
        ans = rng.randint(2, 20)
        a = b * ans
        distractors = [ans + 1, ans - 1 if ans > 1 else ans + 2, ans + rng.choice([2, 3])]
        add_q(templates["division"].format(a=a, b=b), ans, distractors)

    # Solve for X - Linear Addition (30 questions)
    for _ in range(30):
        a = rng.randint(2, 6)
        ans = rng.randint(1, 10)
        b = rng.randint(1, 15)
        c = a * ans + b
        distractors = [ans + 1, ans - 1 if ans > 1 else ans + 2, ans + 3]
        add_q(templates["linear_add"].format(a=a, b=b, c=c), ans, distractors)

    # Prime numbers (15 questions)
    primes = [17, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97]
    composites = [15, 21, 25, 27, 33, 35, 39, 45, 49, 51, 55, 57, 63, 65, 69, 75]
    for _ in range(15):
        correct_p = rng.choice(primes)
        comps = rng.sample(composites, 3)
        add_q(templates["prime"], correct_p, comps)

    # Percentages (15 questions)
    pcts = [10, 20, 25, 30, 40, 50, 60, 75, 80, 90]
    vals = [100, 200, 300, 400, 500, 600, 800, 1000]
    for _ in range(15):
        p = rng.choice(pcts)
        v = rng.choice(vals)
        ans = (p * v) // 100
        distractors = [ans + 5, ans - 5 if ans > 5 else ans + 15, ans + 10]
        add_q(templates["percentage"].format(p=p, v=v), ans, distractors)

    # Area of Rectangle (15 questions)
    for _ in range(15):
        l = rng.randint(5, 20)
        w = rng.randint(2, l - 1)
        ans = l * w
        distractors = [l + w, 2 * (l + w), ans + rng.choice([-5, 5])]
        add_q(templates["area_rect"].format(l=l, w=w), ans, distractors)

    # Area of Triangle (15 questions)
    for _ in range(15):
        b = rng.choice([2, 4, 6, 8, 10, 12])
        h = rng.randint(3, 15)
        ans = (b * h) // 2
        distractors = [b * h, b + h, ans + rng.choice([-2, 2])]
        add_q(templates["area_tri"].format(b=b, h=h), ans, distractors)

    # Solve for X - Linear Division (15 questions)
    for _ in range(15):
        a = rng.randint(2, 8)
        ans = rng.randint(1, 10)
        b = a * ans
        distractors = [ans + 1, ans - 1 if ans > 1 else ans + 2, ans + 3]
        add_q(templates["linear_div"].format(a=a, b=b), ans, distractors)

    # Square Roots (15 questions)
    for _ in range(15):
        ans = rng.randint(2, 15)
        square = ans * ans
        distractors = [ans + 1, ans - 1 if ans > 1 else ans + 2, ans + 3]
        add_q(templates["sqrt"].format(square=square), ans, distractors)

    # Exponents (15 questions)
    for _ in range(15):
        a = rng.choice([2, 3, 5, 10])
        b = rng.choice([2, 3])
        ans = a ** b
        distractors = [ans + a, ans - a if ans > a else ans + 12, ans + 10]
        add_q(templates["exponent"].format(a=a, b=b), ans, distractors)

    # Area of Square (15 questions)
    for _ in range(15):
        side = rng.randint(2, 20)
        ans = side * side
        distractors = [4 * side, side + side, ans + 10]
        add_q(templates["area_sq"].format(side=side), ans, distractors)

    # Perimeter of Square (15 questions)
    for _ in range(15):
        side = rng.randint(2, 20)
        ans = 4 * side
        distractors = [side * side, 2 * side, ans + 5]
        add_q(templates["perimeter_sq"].format(side=side), ans, distractors)

    # GCD (15 questions)
    for _ in range(15):
        factor = rng.choice([2, 3, 4, 5])
        a = factor * rng.choice([2, 3, 5])
        b = factor * rng.choice([7, 11])
        ans = gcd(a, b)
        distractors = [ans + 1, ans - 1 if ans > 1 else ans + 2, ans + 3]
        add_q(templates["gcd"].format(a=a, b=b), ans, distractors)

    # LCM (15 questions)
    for _ in range(15):
        a = rng.choice([4, 6, 8, 9])
        b = rng.choice([10, 12, 15])
        ans = lcm(a, b)
        distractors = [ans + a, ans - b if ans > b else ans + 10, ans + 20]
        add_q(templates["lcm"].format(a=a, b=b), ans, distractors)


    # ==================== CATEGORY: GEOGRAPHY ====================
    geo_temp = GEO_TEMPLATES[lang]
    all_capitals = [c["capital"].get(lang, c["capital"]["en"]) for c in countries_data]
    all_continents = list(set([c["continent"].get(lang, c["continent"]["en"]) for c in countries_data]))
    all_currencies = list(set([c["currency"].get(lang, c["currency"]["en"]) for c in countries_data]))

    for c in countries_data:
        c_name = c["name"].get(lang, c["name"]["en"])

        # Capital question
        correct_cap = c["capital"].get(lang, c["capital"]["en"])
        cap_distractors = rng.sample([cap for cap in all_capitals if cap != correct_cap], 3)
        add_q(geo_temp["capital"].format(country=c_name), correct_cap, cap_distractors)

        # Continent question
        correct_cont = c["continent"].get(lang, c["continent"]["en"])
        cont_distractors = rng.sample([cont for cont in all_continents if cont != correct_cont], 3)
        add_q(geo_temp["continent"].format(country=c_name), correct_cont, cont_distractors)

        # Currency question
        correct_cur = c["currency"].get(lang, c["currency"]["en"])
        cur_distractors = rng.sample([cur for cur in all_currencies if cur != correct_cur], 3)
        add_q(geo_temp["currency"].format(country=c_name), correct_cur, cur_distractors)


    # ==================== CATEGORY: SCIENCE / PLANETS ====================
    planet_temp = PLANET_TEMPLATES[lang]
    all_planet_names = [p["name"].get(lang, p["name"]["en"]) for p in planets_data]

    for p in planets_data:
        correct_name = p["name"].get(lang, p["name"]["en"])
        nickname = p["nickname"].get(lang, p["nickname"]["en"])
        order = p["order"].get(lang, p["order"]["en"])
        
        name_dists = rng.sample([n for n in all_planet_names if n != correct_name], 3)

        # Nickname question
        add_q(planet_temp["nickname"].format(nickname=nickname), correct_name, name_dists)

        # Order question
        add_q(planet_temp["order"].format(order=order), correct_name, name_dists)

    return questions

def generate_all_questions():
    all_qs = []
    for lang in ["en", "hi", "mr", "gu"]:
        lang_qs = generate_questions_for_lang(lang)
        all_qs.extend(lang_qs)
    return all_qs

QUESTIONS_TO_SEED = generate_all_questions()

def seed():
    print(f"Generated a total of {len(QUESTIONS_TO_SEED)} unique, high-quality questions across all languages for seeding.")
    print("Connecting to database using configurations...")
    db = SessionLocal()
    try:
        inserted_count = 0
        for q_data in QUESTIONS_TO_SEED:
            # Check if this question text and language already exists to avoid duplicate seed runs
            exists = db.query(Question).filter(
                Question.text == q_data["text"],
                Question.language == q_data["language"]
            ).first()
            if not exists:
                q = Question(
                    text=q_data["text"],
                    options=json.dumps(q_data["options"]),
                    correct_answer_index=q_data["correct_answer_index"],
                    language=q_data["language"],
                    created_at=datetime.now(timezone.utc)
                )
                db.add(q)
                inserted_count += 1
        
        if inserted_count > 0:
            db.commit()
            print(f"Successfully seeded {inserted_count} new questions into the database!")
        else:
            print("All questions already exist in the database. No new questions inserted.")
    except Exception as e:
        print(f"An error occurred: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed()
