<?php

declare(strict_types=1);

class Dot
{
    private string $projectDir;
    private string $dataDir;
    private string $frontendDir;
    private string $renderedDir;

    private string $articleDir;
    private string $pageDir;
    private string $templateDir;
    private string $articleHtmlDir;
    private string $pageHtmlDir;
    private string $indexFile;

    private string $templateSourceDir;

    public function __construct(string $projectDir)
    {
        $this->projectDir = rtrim(string: $projectDir, characters: '/');

        $this->dataDir = $this->projectDir.".data/";
        $this->frontendDir = $this->projectDir.".frontend/";
        $this->renderedDir = $this->projectDir.".rendered/";

        $this->articleDir = $this->dataDir."articles/";
        $this->pageDir = $this->dataDir."pages/";

        $this->templateDir = $this->frontendDir."html/";

        $this->articleHtmlDir = $this->renderedDir."articles/";
        $this->pageHtmlDir = $this->renderedDir."pages/";
        $this->indexFile = $this->renderedDir."index.html";

        $this->templateSourceDir = __DIR__ . "/project.template/";
    }

    public function init(): void
    {
        $this->ensureDirectory(path: $this->dataDir);
        $this->ensureDirectory(path: $this->frontendDir);
        $this->ensureDirectory(path: $this->renderedDir);

        $this->copyDirectory(src: $this->templateSourceDir.'/frontend/', dest: $this->frontendDir);
        $this->copyDirectory(src: $this->templateSourceDir.'/data/', dest: $this->dataDir);
        $this->copyDirectory(src: $this->templateSourceDir.'/rendered/', dest: $this->renderedDir);

        echo "Initialized project:\n";
        echo "  Data directory: {$this->dataDir}\n";
        echo "  Frontend directory: {$this->frontendDir}\n";
        echo "  Rendered directory: {$this->renderedDir}\n";
    }

    public function createArticle(string $name): void
    {
        $timestamp = date(format: 'Y_m_d_H_i');
        $articlePath = $this->articleDir . $timestamp . '/';
        $this->ensureDirectory(path: $articlePath);

        $markdownFile = $articlePath . $name . '.md';
        file_put_contents(filename: $markdownFile, data: "# New Article\n\nContent goes here.");

        echo "Created article: $markdownFile\n";
    }

    public function createPage(string $name): void
    {
        $pagePath = $this->pageDir.$name.'/';
        $this->ensureDirectory(path: $pagePath);

        $markdownFile = $pagePath.$name.'.md';
        file_put_contents(filename: $markdownFile, data: "# New Page\n\nContent goes here.");

        echo "Created page: $markdownFile\n";
    }

    public function build(): void
    {
        // Initialize index content as a reference variable
        $indexContent = '';

        // Clear the rendered directory
        $this->clearDirectory($this->renderedDir);

        // Build articles and add them to the index
        $this->buildContent($this->articleDir, $this->articleHtmlDir, "article.html", $indexContent, true);

        // Build pages (do not add them to the index)
        $this->buildContent($this->pageDir, $this->pageHtmlDir, "page.html", $indexContent, false);

        // Finalize and write the index file
        $this->finalizeIndex($indexContent);

        echo "Site built successfully at {$this->renderedDir}\n";
    }

    private function buildContent(
        string $sourceDir,
        string $outputDir,
        string $templateFile,
        string &$indexContent,
        bool $addToIndex = false
    ): void
    {
        $items = array_diff(scandir($sourceDir), ['.', '..']);

        foreach ($items as $folder)
        {
            $folderPath = $sourceDir.$folder.'/';
            $markdownFiles = glob($folderPath.'*.md');

            if (!empty($markdownFiles))
            {
                $markdownFile = $markdownFiles[0]; // Fetch the first Markdown file
                $outputFName = pathinfo($markdownFile, PATHINFO_FILENAME).'.html';

                $markdownContent = file_get_contents(filename: $markdownFile);
                $htmlContent = $this->markdownToHtml(markdown: $markdownContent);

                // Extract metadata (e.g., headline)
                preg_match('/^# (.*?)$/m', $markdownContent, $matches);
                $headline = $matches[1] ?? 'Untitled';

                // Generate article/page output
                $templatePath = $this->templateDir . $templateFile;
                $outputContent = $this->renderTemplate(file_get_contents($templatePath), [
                    'headline' => $headline,
                    'content' => $htmlContent,
                ]);

                $outputFolder = $outputDir.$folder.'/';
                $this->ensureDirectory($outputFolder);

                $outputFile = $outputFolder.$outputFName;
                file_put_contents($outputFile, $outputContent);

                // Add the article to the index if required
                if ($addToIndex)
                {
                    $this->addToIndex($headline, "articles/$folder/".$outputFName, $indexContent);
                }
            }
        }
    }

    private function addToIndex(string $headline, string $url, string &$indexContent): void
    {
        // Load the indexItem template
        $indexItem = file_get_contents($this->templateDir . "indexItem.html");

        // Render the index item and append it to the content
        $itemContent = $this->renderTemplate($indexItem, [
            'headline' => $headline,
            'url' => $url,
        ]);

        $indexContent .= $itemContent;
    }

    private function finalizeIndex(string $indexContent): void
    {
        // Load the indexPre and indexPost templates
        $indexPre = file_get_contents($this->templateDir . "indexPre.html");
        $indexPost = file_get_contents($this->templateDir . "indexPost.html");

        // Combine the full index content
        $fullIndexContent = $indexPre.$indexContent.$indexPost;

        // Write the full index file
        file_put_contents($this->indexFile, $fullIndexContent);
    }

    private function ensureDirectory(string $path): void
    {
        if (!is_dir(filename: $path))
        {
            mkdir(directory: $path, permissions: 0777, recursive: true);
        }
    }

    private function copyDirectory(string $src, string $dest): void
    {
        $this->ensureDirectory(path: $dest);
        foreach (scandir(directory: $src) as $item)
        {
            if ($item === '.' || $item === '..')
            {
                continue;
            }

            $srcPath = $src.$item;
            $destPath = $dest.$item;

            if (is_dir(filename: $srcPath))
            {
                $this->copyDirectory(src: $srcPath.'/', dest: $destPath.'/');
            }
            else
            {
                copy(from: $srcPath, to: $destPath);
            }
        }
    }

    private function clearDirectory(string $path): void
    {
        foreach (glob(pattern: $path.'*') as $file)
        {
            if (is_dir(filename: $file))
            {
                $this->clearDirectory(path: $file.'/');
                rmdir(directory: $file);
            }
            else
            {
                unlink(filename: $file);
            }
        }
    }

    private function renderTemplate(string $template, array $placeholders): string
    {
        foreach ($placeholders as $key => $value)
        {
            $template = str_replace(search: "{{" . strtoupper(string: $key) . "}}", replace: $value, subject: $template);
        }

        return $template;
    }

    private function markdownToHtml(string $str): string
    {
        $str = htmlspecialchars(string: $str);

        // Convert headers (e.g., # Header)
        $str = preg_replace_callback('/^(#{1,6})\s*(.+)$/m', function ($matches) {
            $level = strlen($matches[1]);
            return "<h{$level}>{$matches[2]}</h{$level}>";
        }, $str);

        // Convert bold text (**bold** or __bold__)
        $str = preg_replace('/\*\*(.*?)\*\*/', '<strong>$1</strong>', $str);
        $str = preg_replace('/__(.*?)__/', '<strong>$1</strong>', $str);

        // Convert italic text (*italic* or _italic_)
        $str = preg_replace('/\*(.*?)\*/', '<em>$1</em>', $str);
        $str = preg_replace('/_(.*?)_/', '<em>$1</em>', $str);

        // Convert inline code (`code`)
        $str = preg_replace('/`(.*?)`/', '<code>$1</code>', $str);

        // Convert links ([text](url))
        $str = preg_replace('/\[(.*?)\]\((.*?)\)/', '<a href="$2">$1</a>', $str);

        // Convert images (![alt text](url))
        $str = preg_replace('/!\[(.*?)\]\((.*?)\)/', '<img src="$2" alt="$1">', $str);

        // Convert unordered lists (- item or * item)
        $str = preg_replace('/^\s*[-*]\s+(.+)$/m', '<li>$1</li>', $str);
        $str = preg_replace('/(<li>.*<\/li>)/s', '<ul>$1</ul>', $str);

        // Convert ordered lists (1. item, 2. item, etc.)
        $str = preg_replace('/^\s*\d+\.\s+(.+)$/m', '<li>$1</li>', $str);
        $str = preg_replace('/(<li>.*<\/li>)/s', '<ol>$1</ol>', $str);

        // Convert code blocks (``` code block ```)
        $str = preg_replace('/```(.*?)```/s', '<pre><code>$1</code></pre>', $str);

        // Convert new lines to paragraphs
        $paragraphs = preg_split('/\n\s*\n/', trim($str));
        $str = implode("\n", array_map(fn($p) => "<p>{$p}</p>", $paragraphs));

        return $str;
    }
}

// CLI Execution
if ($argc < 2)
{
    echo "Usage: php dot.php <command> <project_dir> [name]\n";
    exit(1);
}

$command = $argv[1];
$projectDir = $argv[2] ?? '';
$name = $argv[3] ?? '';

$generator = new Dot(projectDir: $projectDir);

switch ($command)
{
    case 'init':
        $generator->init();
    break;

    case 'article':
        if ($name)
        {
            $generator->createArticle(name: $name);
        }
        else
        {
            echo "Error: Missing article name.\n";
        }
    break;

    case 'page':
        if ($name)
        {
            $generator->createPage(name: $name);
        }
        else
        {
            echo "Error: Missing page name.\n";
        }
    break;

    case 'build':
        $generator->build();
    break;

    default:
        echo "Unknown command: $command\n";
    break;
}
