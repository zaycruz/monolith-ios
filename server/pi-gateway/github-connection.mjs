import { ConnectionPluginError } from "./connection-router.mjs";

const API_ROOT = "https://api.github.com";
const API_VERSION = "2022-11-28";
const REPOSITORIES_PER_PAGE = 100;
const MAX_REPOSITORIES = 500;
const MAX_REPOSITORY_PAGES = Math.ceil(MAX_REPOSITORIES / REPOSITORIES_PER_PAGE);

export class GitHubConnectionError extends ConnectionPluginError {
  constructor(statusCode, message, type = "github_error") {
    super(statusCode, message, type, "github");
  }
}

function normalizedRepository(repository) {
  if (!Number.isFinite(repository?.id) || typeof repository.full_name !== "string" || !repository.full_name) {
    return null;
  }
  return {
    id: repository.id,
    full_name: repository.full_name,
    private: repository.private === true,
    default_branch: typeof repository.default_branch === "string" ? repository.default_branch : "",
  };
}

export class GitHubConnection {
  constructor({
    token = null,
    appSlug = null,
    fetchFn = globalThis.fetch,
    timeoutMs = 10_000,
    signal = null,
  } = {}) {
    this.token = token?.trim() || null;
    this.appSlug = appSlug?.trim() || null;
    this.fetchFn = fetchFn;
    this.timeoutMs = timeoutMs;
    this.signal = signal;
  }

  get configured() {
    return Boolean(this.token);
  }

  async request(endpoint, { signal = this.signal } = {}) {
    if (!this.configured) {
      throw new GitHubConnectionError(
        503,
        "Connect GitHub from the Monolith app.",
        "connection_unavailable",
      );
    }

    const controller = new AbortController();
    const abort = () => controller.abort(signal?.reason);
    if (signal?.aborted) abort();
    else signal?.addEventListener("abort", abort, { once: true });
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    timer.unref?.();
    try {
      const response = await this.fetchFn(`${API_ROOT}${endpoint}`, {
        headers: {
          accept: "application/vnd.github+json",
          authorization: `Bearer ${this.token}`,
          "x-github-api-version": API_VERSION,
          "user-agent": "monolith-harness-gateway",
        },
        signal: controller.signal,
      });
      if (!response.ok) {
        const unauthorized = response.status === 401 || response.status === 403;
        throw new GitHubConnectionError(
          unauthorized ? 503 : 502,
          unauthorized ? "The GitHub credential on the Monolith server is not authorized." : "GitHub could not complete the request.",
          unauthorized ? "connection_unavailable" : "upstream_error",
        );
      }
      return await response.json();
    } catch (error) {
      if (error instanceof GitHubConnectionError) throw error;
      throw new GitHubConnectionError(502, "The Monolith server could not reach GitHub.", "upstream_error");
    } finally {
      clearTimeout(timer);
      signal?.removeEventListener("abort", abort);
    }
  }

  async identity({ signal = this.signal } = {}) {
    const user = await this.request("/user", { signal });
    if (!Number.isFinite(user?.id) || typeof user.login !== "string" || !user.login) {
      throw new GitHubConnectionError(502, "GitHub returned an invalid account.", "invalid_upstream_response");
    }
    return { id: user.id, login: user.login };
  }

  async status({ signal = this.signal } = {}) {
    if (!this.configured) {
      return {
        id: "github",
        name: "GitHub",
        connected: false,
        account: "",
        description: "Connect your GitHub account from the Monolith app.",
      };
    }
    try {
      const [user, installation] = await Promise.all([
        this.identity({ signal }),
        this.installationState({ signal }),
      ]);
      return {
        id: "github",
        name: "GitHub",
        connected: true,
        account: user.login,
        description: installation.required
          ? "Install the Monolith GitHub App to choose repositories."
          : "Repository access was authorized from the Monolith app.",
        installation_required: installation.required,
        installation_url: installation.url,
      };
    } catch {
      return {
        id: "github",
        name: "GitHub",
        connected: false,
        account: "",
        description: "The GitHub credential on the Monolith server could not be verified.",
      };
    }
  }

  async installations({ signal = this.signal } = {}) {
    if (!this.appSlug) return [];
    const installations = [];
    for (let page = 1; installations.length < 100; page += 1) {
      const response = await this.request(`/user/installations?per_page=100&page=${page}`, { signal });
      if (!Array.isArray(response?.installations)) {
        throw new GitHubConnectionError(502, "GitHub returned an invalid installation list.", "invalid_upstream_response");
      }
      installations.push(...response.installations.slice(0, 100 - installations.length));
      if (response.installations.length < 100) break;
    }
    return installations.filter((installation) => Number.isFinite(installation?.id));
  }

  async installationState({ signal = this.signal } = {}) {
    if (!this.appSlug) {
      throw new GitHubConnectionError(503, "GitHub App OAuth is not configured.", "connection_unavailable");
    }
    const required = (await this.installations({ signal })).length === 0;
    return {
      required,
      url: required ? `https://github.com/apps/${this.appSlug}/installations/new` : null,
    };
  }

  async repositories({ signal = this.signal } = {}) {
    if (!this.configured || !this.appSlug) {
      throw new GitHubConnectionError(503, "Connect GitHub from the Monolith app.", "connection_unavailable");
    }
    return this.installationRepositories({ signal });
  }

  async installationRepositories({ signal = this.signal } = {}) {
    const installations = await this.installations({ signal });
    if (!installations.length) {
      throw new GitHubConnectionError(
        409,
        "Install the Monolith GitHub App before choosing repositories.",
        "installation_required",
      );
    }
    const repositories = [];
    const seen = new Set();
    let requestedPages = 0;
    for (const installation of installations) {
      for (let page = 1;
        repositories.length < MAX_REPOSITORIES && requestedPages < MAX_REPOSITORY_PAGES;
        page += 1) {
        requestedPages += 1;
        const response = await this.request(
          `/user/installations/${installation.id}/repositories?per_page=${REPOSITORIES_PER_PAGE}&page=${page}`,
          { signal },
        );
        if (!Array.isArray(response?.repositories)) {
          throw new GitHubConnectionError(502, "GitHub returned an invalid repository list.", "invalid_upstream_response");
        }
        for (const repository of response.repositories) {
          const normalized = normalizedRepository(repository);
          if (normalized && !seen.has(normalized.id)) {
            seen.add(normalized.id);
            repositories.push(normalized);
          }
          if (repositories.length >= MAX_REPOSITORIES) break;
        }
        if (response.repositories.length < REPOSITORIES_PER_PAGE) break;
      }
      if (repositories.length >= MAX_REPOSITORIES || requestedPages >= MAX_REPOSITORY_PAGES) break;
    }
    return repositories;
  }
}
