package main

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// pbkdf2Iterations is the work factor for password hashing. Raise it as
// hardware improves; stored hashes record their own cost so old rows stay
// verifiable.
const pbkdf2Iterations = 210_000

type user struct {
	ID    string
	Email string
	Hash  string
}

// userStore keeps credentials in memory so the stack runs with no database.
// Replace the map with PostgreSQL queries (infra/docker/initdb/001_schema.sql
// already defines the table) when you wire up persistence.
type userStore struct {
	mu    sync.RWMutex
	byID  map[string]*user
	email map[string]*user
	seq   atomic.Uint64
}

func newUserStore() *userStore {
	return &userStore{byID: map[string]*user{}, email: map[string]*user{}}
}

func (s *userStore) create(email, password string) (*user, error) {
	key := strings.ToLower(strings.TrimSpace(email))

	s.mu.Lock()
	defer s.mu.Unlock()
	if _, exists := s.email[key]; exists {
		return nil, errors.New("email already registered")
	}

	hash, err := hashPassword(password)
	if err != nil {
		return nil, err
	}

	u := &user{ID: newID(s.seq.Add(1)), Email: key, Hash: hash}
	s.byID[u.ID] = u
	s.email[key] = u
	return u, nil
}

func (s *userStore) verify(email, password string) (*user, bool) {
	s.mu.RLock()
	u, ok := s.email[strings.ToLower(strings.TrimSpace(email))]
	s.mu.RUnlock()
	if !ok {
		return nil, false
	}
	if !checkPassword(password, u.Hash) {
		return nil, false
	}
	return u, true
}

func newID(n uint64) string {
	return hex.EncodeToString([]byte(time.Now().UTC().Format("20060102"))) + "-" +
		hex.EncodeToString([]byte{byte(n >> 8), byte(n)})
}

// hashPassword returns "pbkdf2$<iter>$<salt-hex>$<key-hex>".
func hashPassword(password string) (string, error) {
	salt := make([]byte, 16)
	if _, err := rand.Read(salt); err != nil {
		return "", err
	}
	key := pbkdf2SHA256([]byte(password), salt, pbkdf2Iterations, 32)
	return strings.Join([]string{
		"pbkdf2",
		strconv.Itoa(pbkdf2Iterations),
		hex.EncodeToString(salt),
		hex.EncodeToString(key),
	}, "$"), nil
}

func checkPassword(password, encoded string) bool {
	parts := strings.Split(encoded, "$")
	if len(parts) != 4 || parts[0] != "pbkdf2" {
		return false
	}
	iter, err := strconv.Atoi(parts[1])
	if err != nil {
		return false
	}
	salt, err := hex.DecodeString(parts[2])
	if err != nil {
		return false
	}
	want, err := hex.DecodeString(parts[3])
	if err != nil {
		return false
	}

	got := pbkdf2SHA256([]byte(password), salt, iter, len(want))
	return subtle.ConstantTimeCompare(got, want) == 1
}

// pbkdf2SHA256 implements PBKDF2 (RFC 8018) over HMAC-SHA256 using only the
// standard library, so the service builds with no module dependencies.
func pbkdf2SHA256(password, salt []byte, iter, keyLen int) []byte {
	prf := hmac.New(sha256.New, password)
	hashLen := prf.Size()
	blocks := (keyLen + hashLen - 1) / hashLen

	out := make([]byte, 0, blocks*hashLen)
	buf := make([]byte, 4)
	u := make([]byte, hashLen)

	for block := 1; block <= blocks; block++ {
		prf.Reset()
		prf.Write(salt)
		buf[0] = byte(block >> 24)
		buf[1] = byte(block >> 16)
		buf[2] = byte(block >> 8)
		buf[3] = byte(block)
		prf.Write(buf)
		t := prf.Sum(nil)
		copy(u, t)

		for i := 1; i < iter; i++ {
			prf.Reset()
			prf.Write(u)
			u = prf.Sum(u[:0])
			for j := range t {
				t[j] ^= u[j]
			}
		}
		out = append(out, t...)
	}

	return out[:keyLen]
}
