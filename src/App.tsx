import React, { useState, useEffect, useRef, DragEvent } from "react";
import axios from "axios";
import { supabase } from "./lib/supabase";
import { GoogleGenerativeAI } from "@google/generative-ai";
import {
  Upload,
  FileText,
  LogOut,
  Copy,
  ChevronLeft,
  ChevronRight,
  Trash,
} from "lucide-react";
import { Document, Page, pdfjs } from "react-pdf";
import "react-pdf/dist/esm/Page/AnnotationLayer.css";
import "react-pdf/dist/esm/Page/TextLayer.css";
import Highlight from "react-highlight-words";

pdfjs.GlobalWorkerOptions.workerSrc = `//cdnjs.cloudflare.com/ajax/libs/pdf.js/${pdfjs.version}/pdf.worker.min.js`;

// Define types
interface Session {
  user: {
    id: string;
  };
}

interface FileObject {
  id: string;
  name: string;
}

interface SummaryResponse {
  summary: string;
}

type SearchResult = {
  page: number;
  context: string;
  term: string;
  fullText: string;
  summary: string;
};

function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [email, setEmail] = useState<string>("");
  const [password, setPassword] = useState<string>("");
  const [files, setFiles] = useState<FileObject[]>([]);
  const [uploading, setUploading] = useState<boolean>(false);
  const [selectedFileUrl, setSelectedFileUrl] = useState<string | null>(null);
  const [numPages, setNumPages] = useState<number | null>(null);
  const [currentPage, setCurrentPage] = useState<number>(1);
  const [searchTerm, setSearchTerm] = useState<string>("");
  const [foundResults, setFoundResults] = useState<SearchResult[]>([]);
  const [isSearching, setIsSearching] = useState<boolean>(false);
  const [isLoading, setIsLoading] = useState(false);
  const [selectedResult, setSelectedResult] = useState<SearchResult | null>(null);
  const [summary, setSummary] = useState<string>("");
  const [isDragging, setIsDragging] = useState(false);
  const pageRef = useRef<HTMLDivElement | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const apiKey = "AIzaSyCQ-PBg8StgQn--3pd30gjiKI1SrbwEOfg";
  const genAI = new GoogleGenerativeAI(apiKey);

  const defaultSearchTerms = ["breach", "training"];

  const summarizeText = async (text: string): Promise<string> => {
    try {
      const model = genAI.getGenerativeModel({ model: "gemini-pro" });
      const response = await model.generateContent(`Summarize this: ${text}`);
      const summary = response.response.text();
      return summary;
    } catch (error) {
      console.error("Error fetching summary:", error);
      return "Failed to generate summary.";
    }
  };

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      if (session) loadFiles();
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
      if (session) loadFiles();
    });

    return () => {
      subscription?.unsubscribe();
    };
  }, []);

  useEffect(() => {
    if (selectedResult && pageRef.current) {
      const highlightText = () => {
        const textLayer = pageRef.current.querySelector(
          ".react-pdf__Page__textContent"
        );
        if (!textLayer) return;

        const existingHighlights = textLayer.querySelectorAll(".text-highlight");
        existingHighlights.forEach((el) => {
          el.classList.remove("text-highlight");
        });

        const textElements = Array.from(textLayer.querySelectorAll("span"));
        const fullText = textElements.map((el) => el.textContent).join(" ");

        let paragraphStart = -1;
        let paragraphEnd = -1;
        let foundParagraph = false;

        textElements.forEach((element, index) => {
          const elementText = element.textContent || "";
          if (
            elementText
              .toLowerCase()
              .includes(selectedResult.term.toLowerCase()) &&
            !foundParagraph
          ) {
            foundParagraph = true;

            for (let i = index; i >= 0; i--) {
              const prevText = textElements[i].textContent;
              if (prevText?.trim() === "") {
                paragraphStart = i + 1;
                break;
              }
            }
            if (paragraphStart === -1) paragraphStart = 0;

            for (let i = index; i < textElements.length; i++) {
              const nextText = textElements[i].textContent;
              if (nextText?.trim() === "") {
                paragraphEnd = i - 1;
                break;
              }
            }
            if (paragraphEnd === -1) paragraphEnd = textElements.length - 1;
          }
        });

        if (paragraphStart !== -1 && paragraphEnd !== -1) {
          for (let i = paragraphStart; i <= paragraphEnd; i++) {
            textElements[i].classList.add("text-highlight");
          }
        }

        textElements.forEach((element) => {
          const elementText = element.textContent || "";
          if (
            elementText
              .toLowerCase()
              .includes(selectedResult.term.toLowerCase())
          ) {
            element.classList.add("term-highlight");
          }
        });
      };

      setTimeout(highlightText, 100);
    }
  }, [selectedResult, currentPage]);

  const loadFiles = async () => {
    if (!session?.user?.id) return;
    const { data, error } = await supabase.storage
      .from("filestorage")
      .list(session.user.id);
    if (error) {
      console.error("Error loading files:", error);
      return;
    }
    setFiles(data || []);
    return data;
  };

  const handleCopyResults = () => {
    if (foundResults.length === 0) {
      alert("No search results to copy!");
      return;
    }

    const textToCopy = foundResults
      .map((result) => `Page ${result.page}: ${result.context}`)
      .join("\n\n");

    navigator.clipboard
      .writeText(textToCopy)
      .then(() => {
        alert("Search results copied to clipboard!");
      })
      .catch((err) => {
        console.error("Failed to copy:", err);
      });
  };

  const handleDragEnter = (e: DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(true);
  };

  const handleDragLeave = (e: DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);
  };

  const handleDragOver = (e: DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    e.stopPropagation();
  };

  const handleDrop = async (e: DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);

    const files = e.dataTransfer.files;
    if (files.length > 0) {
      const file = files[0];
      if (file.type !== 'application/pdf') {
        alert('Please upload a PDF file');
        return;
      }
      if (file.size > 10 * 1024 * 1024) {
        alert('File size must be less than 10MB');
        return;
      }
      await handleFileUpload(file);
    }
  };

  const handleFileUpload = async (file: File) => {
    setSummary("");
    const fileExt = file.name.split(".").pop();
    const fileName = `${Math.random()}.${fileExt}`;
    const filePath = `${session?.user?.id}/${fileName}`;
    setUploading(true);

    try {
      const { error } = await supabase.storage
        .from("filestorage")
        .upload(filePath, file);
      if (error) throw error;

      const updatedFiles = await loadFiles();
      if (updatedFiles && updatedFiles.length > 0) {
        const newFile = updatedFiles.find((f) => f.name === fileName);
        if (newFile) {
          const url = await getFileUrl(newFile.name);
          setSelectedFileUrl(url);
          setCurrentPage(1);
          setFoundResults([]);
          setSelectedResult(null);
          setSearchTerm(defaultSearchTerms.join("|"));

          await searchPDF(url, defaultSearchTerms.join("|"));
          await fetchSummary(defaultSearchTerms.join("|"));
        }
      }
    } catch (error) {
      alert((error as Error).message);
    } finally {
      setUploading(false);
    }
  };

  const handleFileInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !e.target.files[0]) return;
    const file = e.target.files[0];
    if (file.type !== 'application/pdf') {
      alert('Please upload a PDF file');
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      alert('File size must be less than 10MB');
      return;
    }
    handleFileUpload(file);
  };

  const searchPDF = async (url: string, searchTerm: string) => {
    if (!url || !searchTerm) return;
    setIsLoading(true);
    setIsSearching(true);
    setSelectedResult(null);
    try {
      const pdf = await pdfjs.getDocument(url).promise;
      const results: SearchResult[] = [];
      const searchTerms = searchTerm.toLowerCase().split("|");

      for (let i = 1; i <= pdf.numPages; i++) {
        const page = await pdf.getPage(i);
        const textContent = await page.getTextContent();
        const textItems = textContent.items.map((item) => (item as any).str);
        const fullText = textItems.join(" ");

        for (const term of searchTerms) {
          const regex = new RegExp(`[^,]*${term}[^,]*`, "gi");
          let match;
          while ((match = regex.exec(fullText)) !== null) {
            const startIndex = Math.max(0, match.index);
            const endIndex = Math.min(fullText.length, regex.lastIndex);

            let contextStart = startIndex;
            while (contextStart > 0 && fullText[contextStart - 1] !== ",") {
              contextStart--;
            }

            let contextEnd = endIndex;
            while (
              contextEnd < fullText.length &&
              fullText[contextEnd] !== ","
            ) {
              contextEnd++;
            }
            if (contextEnd < fullText.length) contextEnd++;

            const context = fullText.slice(contextStart, contextEnd).trim();
            const summary = await summarizeText(context);

            results.push({
              page: i,
              context: context,
              term: term,
              fullText: context,
              summary,
            });
          }
        }
      }

      setFoundResults(results);
      setIsLoading(false);
      if (results.length > 0) {
        setCurrentPage(results[0].page);
        setSelectedResult(results[0]);
      }
    } catch (error) {
      console.error("Search error:", error);
    } finally {
      setIsSearching(false);
    }
  };

  const fetchSummary = async (searchTerm: string) => {
    if (!searchTerm) return;
    try {
      const response = await axios.post<SummaryResponse>(
        "https://api.gemini.com/summary",
        { query: searchTerm }
      );

      const trimmedSummary = response.data.summary
        .split(" ")
        .slice(0, 10)
        .join(" ");

      const finalSummary =
        trimmedSummary +
        (response.data.summary.split(" ").length > 10 ? "..." : "");

      setSummary(finalSummary);
    } catch (error) {
      console.error("Error fetching summary:", error);
    }
  };

  const handleDeleteFile = async (fileName: string) => {
    const { error } = await supabase.storage
      .from("filestorage")
      .remove([`${session?.user?.id}/${fileName}`]);

    if (error) {
      alert("Error deleting file: " + error.message);
      return;
    }

    setFiles(files.filter((file) => file.name !== fileName));
    if (selectedFileUrl) {
      const currentFileUrl = await getFileUrl(fileName);
      if (currentFileUrl === selectedFileUrl) {
        setSelectedFileUrl(null);
        setSearchTerm("");
        setFoundResults([]);
        setSelectedResult(null);
      }
    }
  };

  const getFileUrl = async (fileName: string) => {
    const { data } = await supabase.storage
      .from("filestorage")
      .getPublicUrl(`${session?.user?.id}/${fileName}`);
    return data.publicUrl;
  };

  const previewFile = async (fileName: string) => {
    const url = await getFileUrl(fileName);
    setSelectedFileUrl(url);
    setCurrentPage(1);
    setFoundResults([]);
    setSelectedResult(null);
    setSearchTerm(defaultSearchTerms.join("|"));
  };

  const handleResultClick = (result: SearchResult) => {
    setCurrentPage(result.page);
    setSelectedResult(result);
  };

  if (!session) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-primary-50 to-primary-100 flex items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-xl w-full max-w-md p-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-8 text-center">
            I-COMPLY BAA Analyzer™
          </h1>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              supabase.auth.signInWithPassword({ email, password });
            }}
            className="space-y-6"
          >
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Email
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="input-primary h-10 px-3 w-full"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Password
              </label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="input-primary h-10 px-3 w-full"
                required
              />
            </div>
            <button type="submit" className="btn-primary w-full">
              Sign In
            </button>
            <button
              onClick={() => supabase.auth.signUp({ email, password })}
              className="btn-secondary w-full"
            >
              Sign Up
            </button>
          </form>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100">
      <div className="max-w-7xl mx-auto px-4 py-6">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold text-gray-900">
            I-COMPLY BAA Analyzer™
          </h1>
          <button onClick={() => supabase.auth.signOut()} className="btn-danger flex items-center gap-2">
            <LogOut size={20} /> Sign Out
          </button>
        </div>

        <div 
          className={`card mb-8 transition-all duration-300 ${
            isDragging 
              ? 'ring-2 ring-primary-500 bg-primary-50' 
              : 'hover:shadow-lg'
          }`}
          onDragEnter={handleDragEnter}
          onDragOver={handleDragOver}
          onDragLeave={handleDragLeave}
          onDrop={handleDrop}
        >
          <label className="flex flex-col items-center gap-4 cursor-pointer group p-8">
            <div className="p-4 rounded-full bg-primary-50 group-hover:bg-primary-100 transition-colors duration-200">
              <Upload className="w-8 h-8 text-primary-600" />
            </div>
            <div className="text-center">
              <p className="text-lg font-medium text-gray-700 group-hover:text-gray-900">
                {isDragging ? 'Drop your file here' : 'Upload PDF File'}
              </p>
              <p className="text-sm text-gray-500 mt-1">
                Drag and drop or click to select
              </p>
              <p className="text-xs text-gray-400 mt-1">
                PDF files up to 10MB
              </p>
            </div>
            <input
              ref={fileInputRef}
              type="file"
              className="hidden"
              onChange={handleFileInputChange}
              disabled={uploading}
              accept=".pdf"
            />
          </label>
        </div>

        {selectedFileUrl && summary && (
          <div className="summary-box">
            <h3 className="font-semibold text-gray-900 mb-2">Summary</h3>
            <p className="text-gray-700">{summary}</p>
          </div>
        )}

        {selectedFileUrl && (
          <div className="flex gap-6">
            <div className="flex-1">
              <div className="card mb-4">
                <h2 className="text-xl font-semibold text-gray-900 mb-4">
                  PDF Preview
                </h2>
                <div className="pdf-wrapper">
                  <div ref={pageRef} className="pdf-container">
                    <Document
                      file={selectedFileUrl}
                      onLoadSuccess={({ numPages }) => setNumPages(numPages)}
                    >
                      <Page pageNumber={currentPage} />
                    </Document>
                  </div>
                </div>
                <div className="flex justify-between items-center mt-4">
                  <button
                    onClick={() => setCurrentPage((p) => Math.max(p - 1, 1))}
                    className="nav-button"
                    disabled={currentPage <= 1}
                  >
                    <ChevronLeft />
                  </button>
                  <p className="text-sm text-gray-600">
                    Page {currentPage} of {numPages || 0}
                  </p>
                  <button
                    onClick={() =>
                      setCurrentPage((p) => Math.min(p + 1, numPages || 1))
                    }
                    className="nav-button"
                    disabled={currentPage >= (numPages || 1)}
                  >
                    <ChevronRight />
                  </button>
                </div>
              </div>
            </div>

            <div className="w-[450px]">
              {isLoading ? (
                <div className="card flex items-center justify-center p-8">
                  <div className="loading-spinner w-12 h-12" />
                  <p className="ml-3 text-gray-600">Analyzing document...</p>
                </div>
              ) : (
                foundResults.length > 0 && (
                  <div className="card">
                    <div className="flex justify-between items-center mb-4">
                      <h3 className="text-lg font-semibold text-gray-900">
                        Search Results ({foundResults.length})
                      </h3>
                      <button
                        onClick={handleCopyResults}
                        className="btn-secondary flex items-center gap-2 text-sm"
                      >
                        <Copy size={16} /> Copy All
                      </button>
                    </div>
                    <div className="custom-scrollbar overflow-y-auto max-h-[800px]">
                      <div className="space-y-4">
                        {foundResults.map((result, index) => (
                          <div
                            key={index}
                            className={`search-result-item ${
                              selectedResult === result
                                ? "ring-2 ring-primary-500 bg-primary-50"
                                : ""
                            }`}
                            onClick={() => handleResultClick(result)}
                          >
                            <div className="flex justify-between items-center mb-2">
                              <span className="text-sm text-gray-500">
                                {/* Result {index + 1} */}
                              </span>
                              <span className="text-xs  text-primary-800 px-2 py-1 rounded-full">
                                {result.term}
                              </span>
                            </div>
                            <p className="text-sm text-gray-600 mb-2">
                              {result.summary}
                            </p>
                            <div className="text-sm text-gray-800">
                              <Highlight
                                searchWords={searchTerm
                                  .split("|")
                                  .map((term) => term.trim())}
                                autoEscape={true}
                                textToHighlight={result.context}
                              />
                            </div>
                            <div className="mt-2 text-xs text-gray-500">
                              Page {result.page}
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                  </div>
                )
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default App;