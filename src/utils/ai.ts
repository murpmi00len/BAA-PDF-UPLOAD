import OpenAI from 'openai';
import * as pdfjsLib from 'pdfjs-dist';
import { PDFDocumentProxy } from 'pdfjs-dist';

// Set worker path
pdfjsLib.GlobalWorkerOptions.workerSrc = `https://cdnjs.cloudflare.com/ajax/libs/pdf.js/${pdfjsLib.version}/pdf.worker.min.js`;

interface Reference {
  section: string;
  text: string;
}

interface AnalysisResult {
  missingRequirements: Array<{ 
    requirement: string; 
    description: string;
    fix: string;
  }>;
  categoryReferences: {
    complianceReporting: Reference[] | null;
    riskManagement: Reference[] | null;
    training: Reference[] | null;
    securityIncidents: Reference[] | null;
    technicalSafeguards: Reference[] | null;
    phiHandling: Reference[] | null;
    breachProcess: Reference[] | null;
  };
}

async function extractTextFromPDF(file: File): Promise<string> {
  try {
    const arrayBuffer = await file.arrayBuffer();
    const loadingTask = pdfjsLib.getDocument(new Uint8Array(arrayBuffer));
    const pdf: PDFDocumentProxy = await loadingTask.promise;
    let fullText = '';

    for (let i = 1; i <= pdf.numPages; i++) {
      const page = await pdf.getPage(i);
      const textContent = await page.getTextContent();
      const pageText = textContent.items
        .map((item: any) => item.str)
        .join(' ');
      fullText += pageText + '\n';
    }

    return fullText;
  } catch (error) {
    console.error('Error extracting text from PDF:', error);
    throw new Error('Failed to extract text from PDF. Please ensure the file is a valid PDF document.');
  }
}

export async function analyzeDocument(file: File): Promise<AnalysisResult> {
  try {
    // Check if we have an OpenAI API key
    const apiKey = import.meta.env.VITE_OPENAI_API_KEY;
    if (!apiKey) {
      throw new Error('OpenAI API key is missing');
    }

    // Initialize OpenAI client
    const openai = new OpenAI({
      apiKey,
      dangerouslyAllowBrowser: true
    });

    // Extract text from PDF
    console.log('Starting PDF text extraction...');
    const text = await extractTextFromPDF(file);
    if (!text.trim()) {
      throw new Error('No text could be extracted from the PDF');
    }
    console.log('PDF text extracted successfully');

    // Analyze the document using OpenAI
    console.log('Starting OpenAI analysis...');
    const completion = await openai.chat.completions.create({
      model: "gpt-4",
      messages: [
        {
          role: "system",
          content: `You are a HIPAA compliance expert analyzing a Business Associate Agreement (BAA). 
          Extract and categorize relevant sections related to HIPAA compliance requirements.
          Identify missing requirements that should be addressed.
          
          For each found section:
          1. Include the exact section number and heading from the document
          2. Extract the relevant text verbatim
          3. Categorize accurately into the provided categories
          
          For missing requirements:
          1. Identify specific HIPAA requirements not addressed in the BAA
          2. Provide clear descriptions of why they're needed
          3. Suggest specific language to add to the BAA`
        },
        {
          role: "user",
          content: `Analyze this BAA document and provide:
          1. References to existing HIPAA compliance requirements by category
          2. Missing requirements that should be addressed
          
          Document text:
          ${text}`
        }
      ],
      functions: [
        {
          name: "process_baa_analysis",
          description: "Process the BAA analysis results",
          parameters: {
            type: "object",
            properties: {
              categoryReferences: {
                type: "object",
                properties: {
                  complianceReporting: {
                    type: "array",
                    items: {
                      type: "object",
                      properties: {
                        section: { type: "string" },
                        text: { type: "string" }
                      }
                    },
                    nullable: true
                  },
                  riskManagement: {
                    type: "array",
                    items: {
                      type: "object",
                      properties: {
                        section: { type: "string" },
                        text: { type: "string" }
                      }
                    },
                    nullable: true
                  },
                  training: {
                    type: "array",
                    items: {
                      type: "object",
                      properties: {
                        section: { type: "string" },
                        text: { type: "string" }
                      }
                    },
                    nullable: true
                  },
                  securityIncidents: {
                    type: "array",
                    items: {
                      type: "object",
                      properties: {
                        section: { type: "string" },
                        text: { type: "string" }
                      }
                    },
                    nullable: true
                  },
                  technicalSafeguards: {
                    type: "array",
                    items: {
                      type: "object",
                      properties: {
                        section: { type: "string" },
                        text: { type: "string" }
                      }
                    },
                    nullable: true
                  },
                  phiHandling: {
                    type: "array",
                    items: {
                      type: "object",
                      properties: {
                        section: { type: "string" },
                        text: { type: "string" }
                      }
                    },
                    nullable: true
                  },
                  breachProcess: {
                    type: "array",
                    items: {
                      type: "object",
                      properties: {
                        section: { type: "string" },
                        text: { type: "string" }
                      }
                    },
                    nullable: true
                  }
                }
              },
              missingRequirements: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    requirement: { type: "string" },
                    description: { type: "string" },
                    fix: { type: "string" }
                  }
                }
              }
            },
            required: ["categoryReferences", "missingRequirements"]
          }
        }
      ],
      function_call: { name: "process_baa_analysis" }
    });

    console.log('OpenAI analysis completed');

    const functionCall = completion.choices[0].message.function_call;
    if (!functionCall || !functionCall.arguments) {
      throw new Error('Failed to analyze document: No analysis results returned');
    }

    return JSON.parse(functionCall.arguments);
  } catch (error) {
    console.error('Document analysis failed:', error);
    throw new Error(`Failed to analyze document: ${error.message}`);
  }
}