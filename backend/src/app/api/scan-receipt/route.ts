import { NextRequest, NextResponse } from 'next/server';
import { GoogleGenerativeAI } from '@google/generative-ai';

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

export async function POST(request: NextRequest) {
  try {
    if (!GEMINI_API_KEY) {
      return NextResponse.json(
        { error: 'Gemini API key is not configured' },
        { status: 500 }
      );
    }

    const formData = await request.formData();
    const file = formData.get('image') as File | null;

    if (!file) {
      return NextResponse.json(
        { error: 'No image file provided' },
        { status: 400 }
      );
    }

    // Validate file type
    const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'];
    if (!allowedTypes.includes(file.type)) {
      return NextResponse.json(
        { error: 'Invalid file type. Accepted: JPEG, PNG, WebP, HEIC' },
        { status: 400 }
      );
    }

    // Validate file size (max 10MB)
    if (file.size > 10 * 1024 * 1024) {
      return NextResponse.json(
        { error: 'File too large. Maximum size is 10MB' },
        { status: 400 }
      );
    }

    // Convert file to base64
    const bytes = await file.arrayBuffer();
    const base64Image = Buffer.from(bytes).toString('base64');

    // Initialize Gemini
    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash-lite' });

    const prompt = `Analyze this receipt image. Extract all items into a JSON array.
Each object must have:
- "name" (string) - the item name
- "qty" (number) - the quantity purchased
- "price" (number) - the unit price as a clean integer without currency symbols
- "total" (number) - qty * price as a clean integer

Also extract:
- "merchant_name" (string) - the store/restaurant name
- "grand_total" (number) - the overall total from the receipt as a clean integer
- "tax" (number) - tax amount if visible, otherwise 0
- "service_charge" (number) - service charge if visible, otherwise 0

IMPORTANT:
- All prices must be clean integers (no decimals, no currency symbols, no dots/commas as thousand separators)
- If an item name is unclear, use your best context-aware guess
- If quantity is not specified, assume 1
- Return ONLY valid JSON, no markdown code blocks, no extra text

Response format:
{
  "merchant_name": "Store Name",
  "items": [
    {"name": "Item 1", "qty": 1, "price": 10000, "total": 10000}
  ],
  "tax": 0,
  "service_charge": 0,
  "grand_total": 10000
}`;

    const result = await model.generateContent([
      { text: prompt },
      {
        inlineData: {
          mimeType: file.type,
          data: base64Image,
        },
      },
    ]);

    const responseText = result.response.text();

    // Parse the JSON response from Gemini
    let parsedData;
    try {
      // Remove markdown code blocks if present
      let cleanedText = responseText
        .replace(/```json\s*/g, '')
        .replace(/```\s*/g, '')
        .trim();

      parsedData = JSON.parse(cleanedText);
    } catch {
      console.error('Failed to parse Gemini response:', responseText);
      return NextResponse.json(
        { error: 'Struk tidak terbaca, silakan coba lagi.' },
        { status: 422 }
      );
    }

    // Validate the parsed data structure
    if (!parsedData.items || !Array.isArray(parsedData.items) || parsedData.items.length === 0) {
      return NextResponse.json(
        { error: 'Struk tidak terbaca, silakan coba lagi.' },
        { status: 422 }
      );
    }

    // Sanitize and ensure correct types
    const sanitizedItems = parsedData.items.map((item: Record<string, unknown>) => ({
      name: String(item.name || 'Unknown Item'),
      qty: Math.max(1, Math.round(Number(item.qty) || 1)),
      price: Math.round(Number(item.price) || 0),
      total: Math.round(Number(item.total) || 0),
    }));

    const response = {
      merchant_name: String(parsedData.merchant_name || 'Unknown Store'),
      items: sanitizedItems,
      tax: Math.round(Number(parsedData.tax) || 0),
      service_charge: Math.round(Number(parsedData.service_charge) || 0),
      grand_total: Math.round(Number(parsedData.grand_total) || 0),
    };

    return NextResponse.json(response);

  } catch (error: unknown) {
    console.error('Scan receipt error:', error);

    // Check for rate limit / quota errors
    const errorMessage = error instanceof Error ? error.message : String(error);
    if (errorMessage.includes('429') || errorMessage.includes('quota') || errorMessage.includes('Too Many Requests')) {
      return NextResponse.json(
        { error: 'API limit tercapai. Silakan coba lagi dalam beberapa menit.' },
        { status: 429 }
      );
    }

    return NextResponse.json(
      { error: 'Struk tidak terbaca, silakan coba lagi.' },
      { status: 500 }
    );
  }
}
