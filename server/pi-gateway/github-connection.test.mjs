import assert from "node:assert/strict";
import test from "node:test";

import { GitHubConnection, GitHubConnectionError } from "./github-connection.mjs";

test("GitHub connection verifies identity without exposing its token", async () => {
  const requests = [];
  const connection = new GitHubConnection({
    token: "secret-token",
    appSlug: "monolith-test",
    fetchFn: async (url, options) => {
      requests.push({ url, options });
      if (new URL(url).pathname === "/user/installations") {
        return new Response(JSON.stringify({ installations: [{ id: 91 }] }), { status: 200 });
      }
      return new Response(JSON.stringify({ id: 42, login: "octocat", avatar_url: "https://example.invalid/a.png" }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    },
  });

  const status = await connection.status();

  assert.deepEqual(status, {
    id: "github",
    name: "GitHub",
    connected: true,
    account: "octocat",
    description: "Repository access was authorized from the Monolith app.",
    installation_required: false,
    installation_url: null,
  });
  assert.equal(requests.some((request) => request.url === "https://api.github.com/user"), true);
  assert.equal(requests.every((request) => request.options.headers.authorization === "Bearer secret-token"), true);
  assert.doesNotMatch(JSON.stringify(status), /secret-token/);
});

test("GitHub repository listing is normalized and bounded", async () => {
  const connection = new GitHubConnection({
    token: "secret-token",
    appSlug: "monolith-test",
    fetchFn: async (url) => new URL(url).pathname === "/user/installations"
      ? new Response(JSON.stringify({ installations: [{ id: 91 }] }), { status: 200 })
      : new Response(JSON.stringify({ repositories: [
        {
          id: 7,
          name: "monolith",
          full_name: "openaccess-ai-collective/monolith",
          private: true,
          default_branch: "main",
          html_url: "https://github.com/openaccess-ai-collective/monolith",
          updated_at: "2026-08-24T00:00:00Z",
        },
        { id: 8, name: "invalid-without-full-name" },
      ] }), { status: 200 }),
  });

  const repositories = await connection.repositories();

  assert.deepEqual(repositories, [{
    id: 7,
    full_name: "openaccess-ai-collective/monolith",
    private: true,
    default_branch: "main",
  }]);
});

test("GitHub repository listing follows bounded pages", async () => {
  const requestedPages = [];
  const firstPage = Array.from({ length: 100 }, (_, index) => ({
    id: index + 1,
    full_name: `example/repository-${index + 1}`,
    private: false,
    default_branch: "main",
  }));
  const connection = new GitHubConnection({
    token: "secret-token",
    appSlug: "monolith-test",
    fetchFn: async (url) => {
      const parsed = new URL(url);
      if (parsed.pathname === "/user/installations") {
        return new Response(JSON.stringify({ installations: [{ id: 91 }] }), { status: 200 });
      }
      const page = Number(parsed.searchParams.get("page"));
      requestedPages.push(page);
      const body = page === 1
        ? firstPage
        : [{ id: 101, full_name: "example/repository-101", private: true, default_branch: "trunk" }];
      return new Response(JSON.stringify({ repositories: body }), { status: 200 });
    },
  });

  const repositories = await connection.repositories();

  assert.deepEqual(requestedPages, [1, 2]);
  assert.equal(repositories.length, 101);
  assert.equal(repositories.at(-1).full_name, "example/repository-101");
});

test("GitHub repository pagination stops at the explicit page cap even when pages do not add repositories", async () => {
  const requestedPages = [];
  const duplicatePage = Array.from({ length: 100 }, () => ({
    id: 1,
    full_name: "example/duplicate",
    private: false,
    default_branch: "main",
  }));
  const connection = new GitHubConnection({
    token: "secret-token",
    appSlug: "monolith-test",
    fetchFn: async (url) => {
      const parsed = new URL(url);
      if (parsed.pathname === "/user/installations") {
        return new Response(JSON.stringify({ installations: [{ id: 91 }] }), { status: 200 });
      }
      requestedPages.push(Number(parsed.searchParams.get("page")));
      return new Response(JSON.stringify({ repositories: duplicatePage }), { status: 200 });
    },
  });

  const repositories = await connection.repositories();

  assert.deepEqual(requestedPages, [1, 2, 3, 4, 5]);
  assert.equal(repositories.length, 1);
});

test("GitHub connection stays honestly disconnected without an app-authorized token", async () => {
  const connection = new GitHubConnection();

  assert.deepEqual(await connection.status(), {
    id: "github",
    name: "GitHub",
    connected: false,
    account: "",
    description: "Connect your GitHub account from the Monolith app.",
  });
  await assert.rejects(
    connection.repositories(),
    (error) => error instanceof GitHubConnectionError && error.type === "connection_unavailable",
  );
});

test("GitHub App connection lists only repositories from verified installations", async () => {
  const connection = new GitHubConnection({
    token: "user-token",
    appSlug: "monolith-test",
    fetchFn: async (url) => {
      const path = new URL(url).pathname;
      if (path === "/user/installations") {
        return new Response(JSON.stringify({ installations: [{ id: 91 }] }), { status: 200 });
      }
      if (path === "/user/installations/91/repositories") {
        return new Response(JSON.stringify({
          repositories: [{ id: 7, full_name: "example/selected", private: true, default_branch: "main" }],
        }), { status: 200 });
      }
      throw new Error(`unexpected URL ${url}`);
    },
  });

  const repositories = await connection.repositories();

  assert.deepEqual(repositories, [{
    id: 7,
    full_name: "example/selected",
    private: true,
    default_branch: "main",
  }]);
});
